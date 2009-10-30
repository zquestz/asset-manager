# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.4' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require 'rubygems'
require 'desert'

Rails::Initializer.run do |config|
  %w(middleware).each do |dir|
    config.load_paths << "#{RAILS_ROOT}/vendor/plugins/asset_manager/app/#{dir}" 
  end

  config.gem 'greatseth-rvideo',            :lib => 'rvideo'
  config.gem 'mime-types',                  :lib => 'mime/types'
  config.gem 'git',                         :lib => 'git'
  config.gem 'jeweler',                     :lib => 'jeweler'
  config.gem 'mbleigh-acts-as-taggable-on', :lib => 'acts-as-taggable-on'
  config.gem 'RedCloth',                    :lib => 'redcloth'
  config.gem 'mislav-will_paginate',        :lib => 'will_paginate'
  config.gem 'rmagick',                     :lib => 'RMagick'
end

RMAGICK_ENABLE_MAGICK_MEMORY = true unless defined?(RMAGICK_ENABLE_MAGICK_MEMORY)

ENV['PATH'] = '/usr/local/bin:/opt/local/bin:' + ENV['PATH']