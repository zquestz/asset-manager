require 'rvideo'

class EncodedVideo < ActiveRecord::Base
  belongs_to :video
  belongs_to :video_format
  
  validates_presence_of :video_id
  validates_presence_of :video_format_id
  
  has_attached_file :file, :url => "/system/encodedvideos/:attachment/:id/:style/:filename"
  has_attached_file :preview, :url => "/system/encodedvideos/:attachment/:id/:style/:filename", :styles => {:icon => "100x100>", :edit => "200x200>", :master => "500x500>"}
  validates_attachment_presence :file
  
  before_file_post_process :create_preview
  
  # Create preview for the video
  def create_preview(milliseconds=2000)
    if self.video.preview_offset
      milliseconds = self.video.preview_offset
    end

    # Make sure we use the right file, self.file.path doesn't exist before a save
    # This method is public and can be called outside of before_file_post_process
    if self.file.queued_for_write[:original].present?
      current_file = self.file.queued_for_write[:original].path
    else 
      current_file = self.file.path(:original)
    end
    
    # Grab frame for preview
    frame = RVideo::FrameCapturer.capture! :input => "#{current_file}", :offset => "#{(milliseconds/1000).to_s}"
    
    # Set preview file for paperclip
    File.open(frame[0], 'r') do |f|
      self.preview = f
    end
    
    # Might as well set some meta data too. It's easier to get geometry from the image than the videeo.
    image = Paperclip::Geometry.from_file(frame[0])
    self.height = image.try(:height)
    self.width = image.try(:width)
    self.aspect_ratio = image.try(:aspect)
  end
  
  # Embed tag for easy use
  def embed(id="movie")
  	"<embed height=\"#{self.height + 16}\" width=\"#{self.width}\" src=\"#{self.file.url}\" type=\"video/quicktime\" autoplay=\"false\" pluginspage=\"http://www.apple.com/quicktime/download\" enablejavascript=\"true\" id=\"#{id}\" controller=\"true\" />"
  end
  
  # Create encoded video, make sure padding is setup correctly for all aspect ratios
  def process_video
    ffmpeg_command = self.video_format.conversion_command.gsub("%%FFMPEG%%", Video.find(self.video_id).ffmpeg_binary).gsub("%%INPUTFILE%%", "$input_file$")
    ffmpeg_command = ffmpeg_command.gsub("%%OUTPUTFILE%%", "$output_file$" )
    # Regexp that grabs the current encoding size
    ffmpeg_command =~ /-s[ ](([0-9][0-9]?[0-9]?[0-9]?[0-9]?)x([0-9][0-9]?[0-9]?[0-9]?[0-9]?))/
    encoding_dimensions = $1
    encoding_width = $2.to_i
    encoding_height = $3.to_i
    # Get aspect ratios
    encoding_aspect_ratio = (encoding_width.to_f / encoding_height.to_f)
    flipped_ratio = (self.video.height.to_f / self.video.width.to_f)
    pad_details = ""
    # Calculate if padding must be applied on top/bottom or left/right
    if self.video.aspect_ratio >= encoding_aspect_ratio
      new_height = (encoding_width / self.video.aspect_ratio).round
      # Now check that height is divisible by 8 to prevent encode artifacts.
      height_remainder = (new_height % 8)
      new_height = new_height - height_remainder
      new_width = encoding_width - (height_remainder * self.video.aspect_ratio).round
      new_width = ((new_width % 2) == 0) ? new_width : (new_width - 1)
      pad_left = ((encoding_width - new_width) / 2).round
      pad_right = encoding_width - new_width - pad_left
      pad_top = ((encoding_height - new_height) / 2).round
      pad_bottom = encoding_height - new_height - pad_top
      #pad_details = "-padleft #{pad_left} -padright #{pad_right} -padtop #{pad_top} -padbottom #{pad_bottom}"
      pad_details = "-vf pad=#{encoding_width}:#{encoding_height}:#{pad_left}:#{pad_top}"      
      correct_dimensions = "#{encoding_width - (pad_left + pad_right)}x#{encoding_height - (pad_top + pad_bottom)}"
    else
      new_width = (encoding_height / flipped_ratio).round
      # Make sure frame size is divisible by 2, or ffmpeg chokes.
      new_width = ((new_width % 2) == 0) ? new_width : (new_width - 1)
      pad_left = ((encoding_width - new_width) / 2).round
      pad_right = encoding_width - new_width - pad_left
      #pad_details = "-padleft #{pad_left} -padright #{pad_right}"
      pad_details = "-vf pad=#{encoding_width}:#{encoding_height}:#{pad_left}:0"      
      correct_dimensions = "#{encoding_width - (pad_left + pad_right)}x#{encoding_height}"
    end
    ffmpeg_command = ffmpeg_command.gsub("$output_file$", "#{pad_details} $output_file$")
    ffmpeg_command = ffmpeg_command.gsub(encoding_dimensions, correct_dimensions)
    transcoder = RVideo::Transcoder.new
    recipe = ffmpeg_command
    outputfile = Pathname.new(RAILS_ROOT + "/public/system/tmp/" + self.video.file.basename + "-" + self.video_format.title.gsub(" ", "") + "." + self.video_format.output_file_extension)
    processing_valid = true
    begin
      puts "Encoding #{self.video.title == "" ? self.video.title : self.video.file_file_name} in #{self.video_format.title} Format\n"
      transcoder.execute(recipe, {
        :input_file => self.video.file.path,
        :output_file => outputfile.to_s
      })
    rescue RVideo::TranscoderError => e
      processing_valid = false
      puts "Transcode has failed: #{e.class} - #{e}\n"
      self.video.errors.add_to_base "<strong>#{self.video_format.title}</strong><br />Transcode has failed: #{e.class} - #{e}"
    end
    if processing_valid
      # Make sure that qt-faststart is run on the file.
      qtoutputfile = Pathname.new(RAILS_ROOT + "/public/system/tmp/" + self.video.file.basename + "-" + self.video_format.title.gsub(" ", "") + "-qt." + self.video_format.output_file_extension)
      if (system "`which qt-faststart` #{outputfile.to_s} #{qtoutputfile.to_s}")
        # Set qt-faststart encoded video into paperclip file
        File.open(qtoutputfile, 'r') do |f|
          self.file = f
        end
      else
        # Set encoded video into paperclip file
        File.open(outputfile, 'r') do |f|
          self.file = f
        end
      end
      self.save!
      puts "Transcode successful\n"
    end
    outputfile.unlink rescue nil
    qtoutputfile.unlink rescue nil
  end
  
  # Create easy hooks for rvideo data, go go gadget method_missing
  def method_missing(m, *args, &block)
    begin
      super
    rescue
      inspected = RVideo::Inspector.new(:file => self.file.path)
      if inspected.respond_to?(m)
        inspected.send(m, *args, &block)
      else
        super
      end
    end
  end
  
end
