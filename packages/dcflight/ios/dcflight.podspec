Pod::Spec.new do |s|
  s.name = 'dcflight'
  s.version = '0.0.1'
  s.summary = 'Build native apps in dart'
  s.description = <<-DESC
A crossplatform framework.
  DESC
  s.homepage = 'https://github.com/squirelboy360/dcflight'
  s.license = { :file => '../LICENSE' }
  s.author = { 'Tahiru' => 'squirelwares@gmail.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.platform = :ios, '13.5'
  
  # Dependencies
  s.dependency 'Flutter'
  s.dependency 'Yoga' 
  
  # Add plugin registration
  s.public_header_files = 'Classes/**/*.h'
  
  # CRITICAL CHANGE: Set to false - use dynamic framework instead of static
  s.static_framework = false
  
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end