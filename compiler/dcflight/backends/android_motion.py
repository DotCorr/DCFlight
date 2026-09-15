"""Emit native Compose entrance/visibility transitions from shared Motion values."""

def wrap(node, body, expression):
    motion=node.motion
    if motion is None:
        return 'if('+expression(node.visible_when)+') { '+body+' }' if node.visible_when else body
    duration=motion.duration_ms
    spec='androidx.compose.animation.core.tween('+str(duration)+')'
    enter='androidx.compose.animation.fadeIn(animationSpec='+spec+')'
    leave='androidx.compose.animation.fadeOut(animationSpec='+spec+')'
    setup=''
    if motion.kind=='slide':
        setup='val motionDistance = with(androidx.compose.ui.platform.LocalDensity.current) { 16.dp.roundToPx() }; '
        enter+=' + androidx.compose.animation.slideInVertically(animationSpec='+spec+',initialOffsetY={motionDistance})'
        leave+=' + androidx.compose.animation.slideOutVertically(animationSpec='+spec+',targetOffsetY={motionDistance})'
    elif motion.kind=='scale':
        enter+=' + androidx.compose.animation.scaleIn(animationSpec='+spec+',initialScale=0.95f)'
        leave+=' + androidx.compose.animation.scaleOut(animationSpec='+spec+',targetScale=0.95f)'
    elif motion.kind!='fade':raise ValueError('Unsupported shared motion: '+motion.kind)
    visible=expression(node.visible_when) if node.visible_when else 'true'
    return 'run { '+setup+'val motionState = remember { androidx.compose.animation.core.MutableTransitionState(false) }; motionState.targetState = '+visible+'; androidx.compose.animation.AnimatedVisibility(visibleState=motionState,enter='+enter+',exit='+leave+') { '+body+' } }'
