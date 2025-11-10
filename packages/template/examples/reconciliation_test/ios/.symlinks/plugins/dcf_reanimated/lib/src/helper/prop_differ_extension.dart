import 'package:dcflight/framework/renderer/engine/core/mutator/prop_diff_interceptor.dart';

class ReanimatedPropDiffInterceptor extends PropDiffInterceptor {
  @override
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    return elementType == 'ReanimatedView';
  }
  
  @override
  Map<String, dynamic> interceptPropDiff(
    String elementType,
    Map<String, dynamic> oldProps, 
    Map<String, dynamic> newProps,
    Map<String, dynamic> changedProps,
  ) {
    // Don't re-send animation props if animationId is the same
    if (oldProps['animationId'] == newProps['animationId'] && 
        oldProps['animationId'] != null) {
      changedProps.remove('animatedStyle');
      changedProps.remove('autoStart');
      changedProps.remove('animationId');
    }
    return changedProps;
  }
}