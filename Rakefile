# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project'

Bundler.require

require 'bubble-wrap/reactor'
require 'bubble-wrap/media'

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'Netronome'

  app.pods do
    pod 'CocoaAsyncSocket', '~> 0.0.1'
    pod 'DCControls', podspec: '/Users/spierce/git/DCControls/DCControls.podspec'
  end

  # Defaults iPhone only
  # app.device_family = [:iphone, :ipad]
  app.deployment_target = '5.1'

  app.frameworks += %w{CoreAudio CoreData AudioToolbox}

  app.vendor_project('vendor/Audio', :static, :headers_dir => '.')
end
