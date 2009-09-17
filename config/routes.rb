ActionController::Routing::Routes.draw do |map|
  # Routes for images, this includes custom routes for batch options
  map.resources :images
  map.edit_batch_images 'images/*ids/edit', :controller => 'images', :action => 'edit_batches', :conditions => { :method => :get }
  map.update_batch_images 'images/*ids', :controller => 'images', :action => 'update_batches', :conditions => { :method => :put }
  map.destroy_batch_images 'images/*ids', :controller => 'images', :action => 'destroy_batches', :conditions => { :method => :delete}

  # Routes for videos, this includes custom routes for batch options
  map.resources :videos
  map.edit_batch_videos 'videos/*ids/edit', :controller => 'videos', :action => 'edit_batches', :conditions => { :method => :get }
  map.update_batch_videos 'videos/*ids', :controller => 'videos', :action => 'update_batches', :conditions => { :method => :put }
  map.detroy_batch_videos 'videos/*ids', :controller => 'videos', :action => 'destroy_batches', :conditions => { :method => :delete}
end
