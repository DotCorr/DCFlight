Pod::Spec.new do |s|
  s.name             = 'dcf_platform_view'
  s.version          = '0.0.1'
  s.summary          = 'DCF pipeline and DCFPlatformView for Flutter apps'
  s.description      = <<-DESC
  Use runDCFApp instead of runApp for full pipeline control and single DCF surface.
                       DESC
  s.homepage         = 'https://github.com/Dotcorr/dcflight'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dotcorr' => 'licensing@dotcorr.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '13.5'
  s.dependency       'Flutter'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
