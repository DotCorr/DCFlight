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
  s.dependency 'SVGKit', '~> 3.0.0' 
  
  # Skia dependency - built and linked automatically
  s.public_header_files = 'Classes/**/*.h'
  s.preserve_paths = 'Classes/**/*.h', 'Skia/**/*'
  
  s.swift_version = '5.0'
  s.static_framework = true
  
  # Link Skia library from local Skia directory
  # Skia headers use #include "include/core/..." so we need both Skia/ and Skia/include/ in search paths
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia" "$(PODS_TARGET_SRCROOT)/Skia/include" "$(PODS_ROOT)/Headers/Private/dcf_reanimated/Skia" "$(PODS_ROOT)/Headers/Private/dcf_reanimated/Skia/include"',
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia/lib"',
    'OTHER_LDFLAGS' => '-framework Metal -framework MetalKit -framework Foundation -Wl,-dead_strip -Wl,-no_compact_unwind',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SK_METAL=1',
    'OTHER_CPLUSPLUSFLAGS' => '$(OTHER_CFLAGS) -fno-cxx-modules'
  }

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 arm64 arm64e', # Exclude device architectures for simulator
    'ONLY_ACTIVE_ARCH' => 'YES', # Only build active architecture for faster builds
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia" "$(PODS_TARGET_SRCROOT)/Skia/include" "$(PODS_TARGET_SRCROOT)/Classes"',
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Skia/lib"',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'dcf_reanimated-Swift.h',
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-dead_strip -Wl,-no_compact_unwind'
  }
  
  # Note: Library is linked via OTHER_LDFLAGS with full path
  # vendored_libraries can't be used due to CocoaPods 2.6GB file size limit
  # The library is created in Podfile post_install hook and linked directly
end
