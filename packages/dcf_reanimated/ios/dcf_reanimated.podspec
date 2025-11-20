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
  s.source_files = 'Classes/**/*'
  s.platform = :ios, '13.5'
  s.dependency 'dcflight'
  s.dependency 'SVGKit', '~> 3.0.0'
  
  # Skia dependency - built and linked automatically
  s.public_header_files = 'Classes/**/*.h'
  s.private_header_files = 'Classes/**/*-Bridging-Header.h'
  s.preserve_paths = 'Classes/**/*.h'
  
  # Include Skia source files
  s.source_files = 'Classes/**/*.{h,m,mm,swift}'
  
  s.swift_version = '5.0'
  s.static_framework = false
  
  # Link Skia library from local Skia directory
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia/include" "$(PODS_TARGET_SRCROOT)/Skia/include/core" "$(PODS_TARGET_SRCROOT)/Skia/include/gpu" "$(PODS_TARGET_SRCROOT)/Skia/include/gpu/ganesh" "$(PODS_TARGET_SRCROOT)/Skia/include/gpu/ganesh/mtl"',
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia/lib"',
    'OTHER_LDFLAGS' => '-lskia -framework Metal -framework MetalKit -framework Foundation',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SK_METAL=1'
  }

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/Classes/Skia-Bridging-Header.h',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia/include"',
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia/lib"'
  }
  
  # Ensure Skia library is linked
  s.vendored_libraries = 'Skia/lib/libskia.a'
end