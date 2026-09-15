"""One declaration of portable presentation constraints for lowering and schema."""
import re
from .ir import Style, Motion

# Shared visual feedback for enabledWhen, independent of native theme palettes.
DISABLED_OPACITY = 0.45

ICONS = ('camera','photos','image','chat','story','map','user','person','settings','add','close','back','send','search','heart','check','more','location','refresh','flash','flip','swap','share','download','lock','bell','video','trash','logout','inbox','home','mail','calendar','star','flag','clock','folder')
STYLE_FIELDS = {
    'padding': ('padding', {'type':'integer','minimum':0,'maximum':512}),
    'gap': ('gap', {'type':'integer','minimum':0,'maximum':512}),
    'width': ('width', {'type':'integer','minimum':0,'maximum':8192}),
    'height': ('height', {'type':'integer','minimum':0,'maximum':8192}),
    'maxWidth': ('max_width', {'type':'integer','minimum':0,'maximum':8192}),
    'fill': ('fill', {'type':'boolean'}),
    'color': ('color', {'type':'string','pattern':'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$'}),
    'background': ('background', {'type':'string','pattern':'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$'}),
    'borderColor': ('border_color', {'type':'string','pattern':'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$'}),
    'borderWidth': ('border_width', {'type':'integer','minimum':0,'maximum':32}),
    'radius': ('radius', {'type':'integer','minimum':0,'maximum':512}),
    'fontSize': ('font_size', {'type':'integer','minimum':1,'maximum':256}),
    'fontWeight': ('font_weight', {'enum':['regular','medium','semibold','bold']}),
    'align': ('align', {'enum':['start','center','end']}),
    'opacity': ('opacity', {'type':'integer','minimum':0,'maximum':100}),
}
MOTION_SCHEMA = {'type':'object','additionalProperties':False,'required':['kind','durationMs'],
 'properties':{'kind':{'enum':['fade','slide','scale']},'durationMs':{'type':'integer','minimum':0,'maximum':2000}}}

# Legacy key names accepted for compatibility with earlier one-true-source files.
STYLE_ALIASES = {'backgroundColor':'background','cornerRadius':'radius','spacing':'gap','fillWidth':'fill','alignment':'align'}

def style_schema():
    props = {k: v[1] for k, v in STYLE_FIELDS.items()}
    props.update({alias: dict(props[canonical]) for alias, canonical in STYLE_ALIASES.items()})
    return {'type':'object','additionalProperties':False,'properties':props,
            'dependentRequired':{'borderColor':['borderWidth'],'borderWidth':['borderColor']},
            'not':{'required':['fill','width'],'properties':{'fill':{'const':True}}}}

def field_valid(value, spec):
    if 'enum' in spec:return isinstance(value,str) and value in spec['enum']
    kind=spec['type']
    if kind=='boolean':return type(value) is bool
    if kind=='integer':return type(value) is int and spec['minimum'] <= value <= spec['maximum']
    return isinstance(value,str) and re.fullmatch(spec['pattern'],value) is not None

def lower_style(raw, check, path):
    check(isinstance(raw,dict),path+': expected object')
    raw = {STYLE_ALIASES.get(k,k): v for k,v in raw.items()}
    check(not set(raw)-set(STYLE_FIELDS),path+': unknown style properties')
    fields={}
    for key,value in raw.items():
        name,spec=STYLE_FIELDS[key]
        check(field_valid(value,spec),path+'.'+key+': invalid portable style value')
        fields[name]=value
    check(not (fields.get('fill') and fields.get('width') is not None),path+': fill and fixed width conflict')
    check(not ('width' in fields and 'max_width' in fields and fields['width']>fields['max_width']),path+': width exceeds maxWidth')
    check(('border_color' in fields)==('border_width' in fields),path+': borderColor and borderWidth must be declared together')
    return Style(**fields)

def lower_motion(raw,check,path):
    check(isinstance(raw,dict) and set(raw)=={'kind','durationMs'},path+': expected kind and durationMs')
    for key,spec in MOTION_SCHEMA['properties'].items():check(field_valid(raw[key],spec),path+'.'+key+': invalid motion')
    return Motion(raw['kind'],raw['durationMs'])
