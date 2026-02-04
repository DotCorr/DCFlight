import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/framework/renderer/engine/extension_registry.dart';

class ReanimatedInit {
  static bool _initialized = false;
  
  static void ensureInitialized() {
    if (_initialized) return;
    
    // Register the prop diff interceptor
    VDomExtensionRegistry.instance.registerPropDiffInterceptor(
      ReanimatedPropDiffInterceptor()
    );
    
    _initialized = true;
  }
}
