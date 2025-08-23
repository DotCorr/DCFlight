import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';

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
