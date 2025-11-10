Pod::Spec.new do |s|
  s.name             = 'dcf_screens'
  s.version          = '0.0.1'
  s.summary          = 'A module for natively navigating between screens in the DCFlight app using Flutter\'s platform channels.'
  s.description      = <<-DESC
A crossplatform framework.
                       DESC
  s.homepage         = 'https://github.com/squirelboy360/dcflight'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tahiru' => 'squirelboy360@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.platform = :ios, '13.5'
  s.dependency 'dcflight'
  s.dependency 'SVGKit', '~> 3.0.0' 
  
  s.swift_version = '5.0'

  # CRITICAL CHANGE: Set to false - use dynamic framework instead of static
  s.static_framework = false

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end