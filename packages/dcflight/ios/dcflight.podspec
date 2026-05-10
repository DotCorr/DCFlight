Pod::Spec.new do |s|
  s.name = 'dcflight'
  s.version = '0.0.1'
  s.summary = 'Build native apps in Dart – flutter_zero runtime (no Skia/Impeller)'
  s.description = <<-DESC
DCFlight renders native iOS views via FFI. The Dart runtime is DotCorr/flutter_zero –
a stripped Flutter engine with no rendering pipeline. The Flutter iOS embedding
(FlutterEngine, FlutterAppDelegate) is retained for tooling compatibility;
only the engine binary differs from Google Flutter.
  DESC
  s.homepage = 'https://github.com/Dotcorr/dcflight'
  s.license = { :file => '../LICENSE' }
  s.author = { 'Tahiru' => 'squirelwares@gmail.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.platform = :ios, '13.5'
  
  # flutter_zero still provides Flutter.xcframework for the iOS embedding layer.
  # Only the engine binary (dylib) differs – no Skia/Impeller, pure Dart runtime.
  s.dependency 'Flutter'
  s.dependency 'Yoga', '~> 3.0.0' 
  
  # Add plugin registration
  s.public_header_files = 'Classes/**/*.h'
  
  # CRITICAL CHANGE: Set to false - use dynamic framework instead of static
  s.static_framework = false
  
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'dcflight-Swift.h',
    'SWIFT_OBJC_BRIDGING_HEADER' => '',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'PRODUCT_MODULE_NAME' => 'dcflight',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${BUILT_PRODUCTS_DIR}/dcflight.framework/Headers" "${CONFIGURATION_BUILD_DIR}/dcflight.build/Objects-normal/${CURRENT_ARCH}"'
  }
end