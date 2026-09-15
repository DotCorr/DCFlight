"""Compile shared presentation into concrete SwiftUI modifiers and native views."""
import re
from dataclasses import dataclass, replace
from .common import expression, symbol
from ..ir import Reference
from ..presentation import DISABLED_OPACITY


ICONS = {
    'camera': 'camera', 'photos': 'photo.on.rectangle', 'image': 'photo',
    'chat': 'bubble.left.and.bubble.right', 'story': 'circle.dashed', 'map': 'map',
    'user': 'person', 'person': 'person', 'settings': 'gearshape', 'add': 'plus',
    'close': 'xmark', 'back': 'chevron.left', 'send': 'paperplane', 'search': 'magnifyingglass',
    'heart': 'heart', 'check': 'checkmark', 'more': 'ellipsis', 'location': 'location',
    'refresh': 'arrow.clockwise', 'flash': 'bolt', 'flip': 'arrow.triangle.2.circlepath.camera',
    'swap': 'arrow.left.arrow.right', 'share': 'square.and.arrow.up', 'download': 'arrow.down.to.line',
    'lock': 'lock', 'bell': 'bell', 'video': 'video', 'trash': 'trash', 'logout': 'rectangle.portrait.and.arrow.right',
    'inbox': 'tray', 'home': 'house', 'mail': 'envelope', 'calendar': 'calendar',
    'star': 'star', 'flag': 'flag', 'clock': 'clock', 'folder': 'folder',
}


@dataclass(frozen=True)
class Presentation:
    body: str
    declarations: str = ''


def color(value):
    if not isinstance(value, str) or not re.fullmatch(r'#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?', value):
        raise ValueError('Color must be #RRGGBB or #RRGGBBAA')
    channels=[int(value[index:index+2],16)/255 for index in (1,3,5)]
    opacity=int(value[7:9],16)/255 if len(value)==9 else 1
    return 'Color(.sRGB, red: '+format(channels[0],'.10g')+', green: '+format(channels[1],'.10g')+', blue: '+format(channels[2],'.10g')+', opacity: '+format(opacity,'.10g')+')'


def _value(style, name):
    return getattr(style,name,None) if style is not None else None


def _align(style, row=False):
    align=_value(style,'align') or 'start'
    return ({'start':'top','center':'center','end':'bottom'} if row else {'start':'leading','center':'center','end':'trailing'})[align]


def _image(source):
    # The branching is native content handling, not a runtime UI registry or renderer.
    return '''Group {
    if '''+source+'''.hasPrefix("asset:") {
        Image(String('''+source+'''.dropFirst(6))).resizable().scaledToFit()
    } else if let imageURL = URL(string: '''+source+'''), imageURL.scheme?.lowercased() == "https" {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty: ProgressView().accessibilityLabel("Loading image")
            case .success(let image): image.resizable().scaledToFit()
            case .failure: Image(systemName: "photo.badge.exclamationmark").accessibilityLabel("Image unavailable")
            @unknown default: Image(systemName: "photo").accessibilityLabel("Image unavailable")
            }
        }
    } else {
        Image(systemName: "photo.badge.exclamationmark").accessibilityLabel("Image unavailable")
    }
}'''


def render(node, default_body, expression_fn=expression, children_source=None):
    style=getattr(node,'style',None)
    motion=getattr(node,'motion',None)
    visible=getattr(node,'visible_when',None)
    props=node.props()
    children=children_source if children_source is not None else '\n'.join(symbol(child.id)+'(model: model)' for child in node.children)
    body=default_body
    if node.capability in ('row','column','card'):
        container='HStack' if node.capability=='row' else 'VStack'
        gap=_value(style,'gap')
        body=container+'(alignment: .'+_align(style,node.capability=='row')+', spacing: '+str(gap if gap is not None else 0)+') {\n'+children+'\n}'
    elif node.capability=='scroll':
        body='ScrollView(.vertical) {\n'+children+'\n}'
    elif node.capability=='spacer':
        body='Spacer(minLength: 0)'
    elif node.capability=='icon':
        value=props['name']
        if isinstance(value,Reference) or value.value not in ICONS:
            raise ValueError('Icon name must be a supported literal semantic icon')
        body='Image(systemName: "'+ICONS[value.value]+'").font(.system(size: 24)).accessibilityHidden(true)'
    elif node.capability=='image':
        body=_image(expression_fn(props['source'],'ios'))
    elif node.capability=='progressBar':
        body='ProgressView(value: Double('+expression_fn(props['value'],'ios')+'), total: 100).progressViewStyle(.linear)'
    modifiers=[]
    padding=_value(style,'padding')
    if padding is not None: modifiers.append('.padding('+str(padding)+')')
    width=_value(style,'width');height=_value(style,'height');maximum=_value(style,'max_width')
    if width is not None or height is not None:
        args=[]
        if width is not None: args.append('width: '+str(width))
        if height is not None: args.append('height: '+str(height))
        args.append('alignment: .'+_align(style,node.capability=='row'))
        modifiers.append('.frame('+', '.join(args)+')')
    if maximum is not None or (_value(style,'fill') and width is None):
        limit=str(maximum) if maximum is not None else '.infinity'
        modifiers.append('.frame(maxWidth: '+limit+', alignment: .'+_align(style,node.capability=='row')+')')
    size=_value(style,'font_size');weight=_value(style,'font_weight')
    if size is not None: modifiers.append('.font(.system(size: authoredFontSize, weight: .'+(weight or 'regular')+'))')
    elif weight is not None: modifiers.append('.fontWeight(.'+weight+')')
    foreground=_value(style,'color')
    if foreground is not None: modifiers.extend(['.foregroundStyle('+color(foreground)+')','.tint('+color(foreground)+')'])
    background=_value(style,'background')
    if background is not None: modifiers.append('.background('+color(background)+')')
    radius=_value(style,'radius')
    if radius is not None: modifiers.append('.clipShape(RoundedRectangle(cornerRadius: '+str(radius)+'))')
    border=_value(style,'border_color');border_width=_value(style,'border_width')
    if border is not None and border_width is not None and border_width>0:
        modifiers.append('.overlay(RoundedRectangle(cornerRadius: '+str(radius or 0)+').strokeBorder('+color(border)+', lineWidth: '+str(border_width)+'))')
    opacity=_value(style,'opacity')
    if opacity is not None: modifiers.append('.opacity('+format(opacity/100,'.10g')+')')
    if _value(style,'align') is not None and node.capability in ('text','counter','textField','secureField'):
        modifiers.append('.multilineTextAlignment(.'+{'start':'leading','center':'center','end':'trailing'}[style.align]+')')
    body+='\n'+'\n'.join(modifiers) if modifiers else ''
    declarations=('    @ScaledMetric(relativeTo: .body) private var authoredFontSize: Double = '+str(size)+'\n') if size is not None else ''
    if motion is not None:
        declarations+='    @Environment(\\.accessibilityReduceMotion) private var reduceMotion\n'
        duration=motion.duration_ms/1000
        animation='reduceMotion ? nil : .easeInOut(duration: '+format(duration,'.10g')+')'
        transition={'fade':'.opacity','slide':'.offset(y: 16).combined(with: .opacity)','scale':'.scale(scale: 0.95).combined(with: .opacity)'}[motion.kind]
        if visible is not None:
            body+='\n.transition(reduceMotion ? .identity : '+transition+')'
        else:
            declarations+='    @State private var presentationAppeared = false\n'
            body+='\n.opacity(reduceMotion || presentationAppeared ? 1 : 0)'
            if motion.kind=='slide': body+='\n.offset(y: reduceMotion || presentationAppeared ? 0 : 16)'
            if motion.kind=='scale': body+='\n.scaleEffect(reduceMotion || presentationAppeared ? 1 : 0.95)'
            body+='\n.animation('+animation+', value: presentationAppeared)\n.onAppear { presentationAppeared = true }\n.onDisappear { presentationAppeared = false }'
        for value in props.values():
            if isinstance(value,Reference): body+='\n.animation('+animation+', value: '+expression_fn(value,'ios')+')'
    if visible is not None:
        condition=expression_fn(visible,'ios')
        body='Group {\n    if '+condition+' {\n'+body+'\n    }\n}'
        if motion is not None: body+='\n.animation('+animation+', value: '+condition+')'
    if node.enabled_when is not None:
        body += '\n.disabled(!(' + expression_fn(node.enabled_when,'ios') + '))'
        body += '\n.opacity(' + expression_fn(node.enabled_when,'ios') + ' ? 1 : ' + str(DISABLED_OPACITY) + ')'
    return Presentation(body,declarations)


def render_button(node, action, expression_fn=expression):
    """Keep authored geometry inside the native interactive label."""
    label_node = replace(node, capability='text', action=None, motion=None,
                         visible_when=None, enabled_when=None)
    label = render(label_node, 'Text('+expression_fn(node.props()['text'], 'ios')+')',
                   expression_fn=expression_fn)
    radius = _value(node.style, 'radius')
    shape = 'RoundedRectangle(cornerRadius: '+str(radius)+')' if radius is not None else 'Rectangle()'
    body = 'Button(action: '+action+') {\n'+label.body+'\n.contentShape('+shape+')\n}.buttonStyle(.plain)'
    outer=render(replace(node, style=None), body, expression_fn=expression_fn)
    return Presentation(outer.body,label.declarations+outer.declarations)
