# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'ScreenShareDemo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ScreenShareDemo

end

target 'ScreenShareUploader' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  pod 'GoogleWebRTC'
#  pod 'Socket.IO-Client-Swift', '~> 16.0.1'
  pod 'Socket.IO-Client-Swift', '16.0.1'
  pod 'Starscream', '4.0.4'
  # Pods for ScreenShareUploader

end

target 'ScreenShareUploaderSetupUI' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ScreenShareUploaderSetupUI

end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Do either this:
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      # or this:
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end