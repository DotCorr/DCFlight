Pod::Spec.new do |s|
  s.name             = 'dcf_reanimated'
  s.version          = '0.0.1'
  s.summary          = 'A module for animating components directly on the UI thread for dcflight'
  s.description      = <<-DESC
A crossplatform framework.
                       DESC
  s.homepage         = 'https://github.com/squirelboy360/dcflight'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tahiru' => 'test@test.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m,mm,swift}'
  s.platform = :ios, '13.5'
  s.dependency 'dcflight'
  s.dependency 'dcf_primitives'
  s.dependency 'SVGKit', '~> 3.0.0' 
  
  # Use Flutter engine's internal Skia/Impeller - no separate bundle needed
  s.public_header_files = 'Classes/**/*.h'
  
  s.swift_version = '5.0'
  s.static_framework = true
  
  # Minimal configuration - Flutter engine provides Skia
  s.xcconfig = {
    'OTHER_LDFLAGS' => '-framework Metal -framework MetalKit -framework Foundation',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386', 
    'ONLY_ACTIVE_ARCH' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'dcf_reanimated-Swift.h'
  }
end
