/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
/// Development-time app authoring. These objects never ship in native apps.
library;

Object? _json(Object? value) {
  if (value is Ref) return {'ref': value.name};
  if (value is FieldRef) return {'field': {'collection':value.collection,'name':value.name}};
  if (value is Node) return value.toJson();
  if (value is Predicate) return value.toJson();
  if (value is Map<Object?, Object?>) {
    if(value.keys.any((key)=>key is! String)) throw ArgumentError("Authoring maps require string keys");
    return value.map((key, item) => MapEntry(key as String, _json(item)));
  }
  if (value is Iterable) return value.map((item) => _json(item)).toList();
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is ResponseCollection) return value.toJson();
  if (value is MediaRef) return {'media':value.name};
  if (value is MediaBody) return {'mediaBody':_json(value.source)};
  if (value is MediaMetadata) return value.toJson();
  if (value is Length) return value.toJson();
  if (value is Flag) return value.toJson();
  if (value is Utf8Length) return value.toJson();
  throw ArgumentError('Unsupported authoring value: ${value.runtimeType}');
}

class App {
  final int version;
  final String id, name;
  final Map<String, Object> state;
  final List<Action> actions;
  final Node root;
  final Logic? logic;
  final Service? service;
  final Theme? theme;
  final List<NativeModule> modules;
  final List<NativeOperation> nativeOperations;
  final String? sdkCatalog;
  final List<Screen> routes;
  final List<NavigationAction> navigationActions;
  final List<FlowAction> flowActions;
  final List<Collection> collections;
  final List<MediaState> media;
  final List<Timer> timers;
  final List<CameraResource> cameraResources;
  final Map<String,String> permissionDescriptions;
  final MapConfig? mapConfig;
  final Transport? transport;
  final String? initialAction;
  final NativeConfiguration? nativeConfiguration;
  const App({
    this.version = 1,
    this.nativeOperations=const [], this.sdkCatalog,
    required this.id,
    required this.name,
    this.state = const {},
    this.actions = const [],
    required this.root,
    this.logic,
    this.service,
    this.theme,
    this.modules = const [],
    this.routes = const [],
    this.navigationActions = const [],
    this.flowActions = const [],
    this.collections = const [],
    this.media = const [],
    this.timers = const [],
    this.cameraResources=const [],
    this.permissionDescriptions=const {},
    this.mapConfig,
    this.transport,
    this.initialAction,
    this.nativeConfiguration,
  });

  Map<String, Object?> toJson() => {
    'version': version,
    'id': id,
    'name': name,
    'state': _json(state),
    'actions': actions.map((action) => action.toJson()).toList(),
    'root': root.toJson(),
    if(cameraResources.isNotEmpty)'cameraResources':cameraResources.map((c)=>{'id':c.id}).toList(),
    if(permissionDescriptions.isNotEmpty)'permissionDescriptions':permissionDescriptions,
    if(mapConfig!=null)'mapConfig':mapConfig!.toJson(),
    if(timers.isNotEmpty)'timers':timers.map((t)=>t.toJson()).toList(),
    if(media.isNotEmpty)'media':media.map((m)=>{'name':m.name}).toList(),
    if(collections.isNotEmpty)'collections':collections.map((c)=>c.toJson()).toList(),
    if(nativeOperations.isNotEmpty)'nativeOperations':nativeOperations.map((o)=>o.toJson()).toList(),
    if(sdkCatalog!=null)'sdkCatalog':sdkCatalog,
    if(flowActions.isNotEmpty)'flowActions':flowActions.map((f)=>f.toJson()).toList(),
    if(transport!=null)'transport':transport!.toJson(),
    if(initialAction!=null)'initialAction':initialAction,
    if(nativeConfiguration!=null)'nativeConfiguration':nativeConfiguration!.toJson(),
    if (logic != null) 'logic': logic!.toJson(),
    if (service != null) 'service': service!.toJson(),
    if (theme != null) 'theme': theme!.toJson(),
    if (modules.isNotEmpty) 'modules': modules.map((module) => module.toJson()).toList(),
    if (routes.isNotEmpty) 'routes': routes.map((route) => route.toJson()).toList(),
    if (navigationActions.isNotEmpty) 'navigationActions': navigationActions.map((action) => action.toJson()).toList(),
  };
}

class RoutedApp extends App {
  const RoutedApp({required super.id, required super.name, required super.root,
    required List<Screen> screens, super.state, super.actions, super.logic,
    super.modules, super.nativeOperations, super.sdkCatalog, super.navigationActions,super.cameraResources,super.permissionDescriptions,super.mapConfig,super.timers,super.media,super.collections,super.flowActions,super.transport,super.initialAction,super.nativeConfiguration}) : super(version: 2, routes: screens);
}

/// Development-time native project metadata, validated before project generation.
class NativeConfiguration {
  final IOSConfiguration? ios;
  final AndroidConfiguration? android;
  const NativeConfiguration({this.ios, this.android});
  Map<String, Object?> toJson() => {
    if (ios != null) 'ios': ios!.toJson(),
    if (android != null) 'android': android!.toJson(),
  };
}

class IOSConfiguration {
  final Map<String, PlistValue> infoPlist, entitlements;
  final List<int> deploymentTarget;
  const IOSConfiguration({this.infoPlist = const {}, this.entitlements = const {}, this.deploymentTarget = const [17, 0]});
  Map<String, Object?> toJson() => {
    'deploymentTarget': deploymentTarget,
    'infoPlist': infoPlist.map((key, value) => MapEntry(key, value.toJson())),
    'entitlements': entitlements.map((key, value) => MapEntry(key, value.toJson())),
  };
}

class AndroidConfiguration {
  final int compileSdk, minSdk, targetSdk;
  final bool validateNativeAvailability;
  final ManifestElement? manifest;
  final List<String> sourceSets;
  final Map<String, String> namespaces;
  const AndroidConfiguration({this.manifest, this.sourceSets = const ['debug', 'release'], this.namespaces = const {}, this.compileSdk = 35, this.minSdk = 26, this.targetSdk = 35, this.validateNativeAvailability = false});
  Map<String, Object?> toJson() => {
    if (manifest != null) 'manifest': manifest!.toJson(),
    'sourceSets': sourceSets,
    'compileSdk': compileSdk, 'minSdk': minSdk, 'targetSdk': targetSdk,
    'validateNativeAvailability': validateNativeAvailability,
    if (namespaces.isNotEmpty) 'namespaces': namespaces,
  };
}

/// A structured native manifest element; attributes are strings, never raw XML.
class ManifestElement {
  final String tag;
  final Map<String, String> attributes;
  final List<ManifestElement> children;
  const ManifestElement(this.tag, {this.attributes = const {}, this.children = const []});
  Map<String, Object?> toJson() => {
    'tag': tag,
    'attributes': attributes,
    'children': children.map((child) => child.toJson()).toList(),
  };
}

/// Explicit property-list types preserve integers, dates and binary data.
/// Data uses base64 and dates use ISO 8601 strings; the compiler validates both.
sealed class PlistValue {
  const PlistValue._();
  const factory PlistValue.string(String value) = _PlistString;
  const factory PlistValue.integer(int value) = _PlistInteger;
  const factory PlistValue.real(double value) = _PlistReal;
  const factory PlistValue.boolean(bool value) = _PlistBoolean;
  const factory PlistValue.data(String value) = _PlistData;
  const factory PlistValue.date(String value) = _PlistDate;
  const factory PlistValue.array(List<PlistValue> value) = _PlistArray;
  const factory PlistValue.dictionary(Map<String, PlistValue> value) = _PlistDictionary;
  Map<String, Object?> toJson();
}

final class _PlistString extends PlistValue {
  final String value;
  const _PlistString(this.value) : super._();
  @override Map<String, Object?> toJson() => {'type': 'string', 'value': value};
}

final class _PlistInteger extends PlistValue {
  final int value;
  const _PlistInteger(this.value) : super._();
  @override Map<String, Object?> toJson() => {'type': 'integer', 'value': value};
}

final class _PlistReal extends PlistValue {
  final double value;
  const _PlistReal(this.value) : super._();
  @override Map<String, Object?> toJson() => {'type': 'real', 'value': value};
}

final class _PlistBoolean extends PlistValue {
  final bool value;
  const _PlistBoolean(this.value) : super._();
  @override Map<String, Object?> toJson() => {'type': 'boolean', 'value': value};
}

final class _PlistData extends PlistValue {
  final String value;
  const _PlistData(this.value) : super._();
  @override Map<String, Object?> toJson() => {'type': 'data', 'value': value};
}

final class _PlistDate extends PlistValue {
  final String value;
  const _PlistDate(this.value) : super._();
  @override Map<String, Object?> toJson() => {'type': 'date', 'value': value};
}

final class _PlistArray extends PlistValue {
  final List<PlistValue> value;
  const _PlistArray(this.value) : super._();
  @override Map<String, Object?> toJson() => {
    'type': 'array', 'value': value.map((item) => item.toJson()).toList(),
  };
}

final class _PlistDictionary extends PlistValue {
  final Map<String, PlistValue> value;
  const _PlistDictionary(this.value) : super._();
  @override Map<String, Object?> toJson() => {
    'type': 'dictionary', 'value': value.map((key, item) => MapEntry(key, item.toJson())),
  };
}

enum ScreenPresentation { page, sheet, fullScreen }

enum TitleDisplay { compact, large }

class Screen {
  final String id, title;
  final Node body;
  final ScreenPresentation presentation;
  final TitleDisplay titleDisplay;
  const Screen({required this.id, required this.title, required this.body,
    this.presentation = ScreenPresentation.page, this.titleDisplay = TitleDisplay.compact});
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'body': body.toJson(),
    'presentation': presentation.name, 'titleDisplay': titleDisplay.name};
}

abstract class NativeNavigationAppearance {
  const NativeNavigationAppearance();
  Map<String,Object> toJson();
}
class NavigationAppearance extends NativeNavigationAppearance {
  final String? accent, surface;
  const NavigationAppearance({this.accent,this.surface});
  @override Map<String,Object> toJson()=>{if(accent!=null)'accent':accent!,if(surface!=null)'surface':surface!};
}
class TabAppearance extends NativeNavigationAppearance {
  final String? selectedForeground, unselectedForeground, surface;
  const TabAppearance({this.selectedForeground,this.unselectedForeground,this.surface});
  @override Map<String,Object> toJson()=>{if(selectedForeground!=null)'selectedForeground':selectedForeground!,if(unselectedForeground!=null)'unselectedForeground':unselectedForeground!,if(surface!=null)'surface':surface!};
}

class NavigationStack extends Node {
  NavigationStack({required super.id, required String initialRoute, NavigationAppearance? appearance})
    : super(type: 'navigationStack', props: {'initialRoute': initialRoute}, appearance: appearance);
}

class NavigationAction {
  final String id, operation;
  final String? route;
  const NavigationAction.push(this.route, {required this.id}) : operation = 'push';
  const NavigationAction.replace(this.route, {required this.id}) : operation = 'replace';
  const NavigationAction.resetRoot(this.route, {required this.id}) : operation = 'resetRoot';
  const NavigationAction.present(this.route, {required this.id}) : operation = 'present';
  const NavigationAction.back({required this.id}) : operation = 'back', route = null;
  const NavigationAction.dismiss({required this.id}) : operation = 'dismiss', route = null;
  Map<String, Object?> toJson() => {'id': id, 'op': operation, if (route != null) 'route': route};
}

class NativeModule {
  final String id, platform, lock;
  const NativeModule({required this.id, required this.platform, required this.lock});
  Map<String, Object?> toJson() => {'id': id, 'platform': platform, 'lock': lock};
}

class Node {
  final String id, type;
  final Map<String, Object> props;
  final List<Node> children;
  final String? action;
  final Style? style;
  final Motion? motion;
  final Object? visibleWhen;
  final Object? enabledWhen;
  final NativeNavigationAppearance? appearance;
  const Node({
    required this.id,
    required this.type,
    this.props = const {},
    this.children = const [],
    this.action,
    this.style,
    this.motion,
    this.visibleWhen,
    this.enabledWhen,
    this.appearance,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'props': _json(props),
    if (children.isNotEmpty)
      'children': children.map((node) => node.toJson()).toList(),
    if (action != null) 'action': action,
    if (style != null) 'style': style!.toJson(),
    if (motion != null) 'motion': motion!.toJson(),
    if (visibleWhen != null) 'visibleWhen': _json(visibleWhen),
    if (enabledWhen != null) 'enabledWhen': _json(enabledWhen),
    if (appearance != null) 'appearance': appearance!.toJson(),
  };
}

/// A typed reference to state in the canonical application, not Dart runtime state.
abstract class Reference<T> {}

class Ref<T> implements Reference<T> {
  final String name;
  const Ref({required this.name});
  const Ref.of(this.name);
}

/// A native boolean expression serialized for compiler type checking.
/// State and row references remain expressions; they are never evaluated here.
abstract class Predicate {
  const Predicate();
  Map<String, Object?> toJson();
}

class StringIsEmpty extends Predicate {
  final Object value;
  const StringIsEmpty(this.value);
  @override
  Map<String, Object?> toJson() => {'isEmpty': _json(value)};
}

class BooleanNot extends Predicate {
  final Object value;
  const BooleanNot(this.value);
  @override
  Map<String, Object?> toJson() => {'not': _json(value)};
}

class BooleanAll extends Predicate {
  final List<Object> values;
  const BooleanAll(this.values);
  @override
  Map<String, Object?> toJson() => {'all': _json(values)};
}

class BooleanAny extends Predicate {
  final List<Object> values;
  const BooleanAny(this.values);
  @override
  Map<String, Object?> toJson() => {'any': _json(values)};
}

class Action {
  final String id, op;
  final String? target;
  final Object? value;
  final String? function;
  final String? failure;
  final List<Object> args;
  const Action({
    required this.id,
    required this.op,
    this.target,
    this.value,
    this.function,
    this.failure,
    this.args = const [],
  });
  const Action.call({
    required this.id,
    required this.function,
    required this.target,
    this.args = const [],
    this.failure,
  }) : op = 'call',
       value = null;
  const Action.set({
    required this.id,
    required this.target,
    required this.value,
  }) : op = 'set',
       failure = null,
       function = null,
       args = const [];
  const Action.toggle({required this.id, required this.target})
    : op = 'toggle',
      failure = null,
      value = null,
      function = null,
      args = const [];

  Map<String, Object?> toJson() => {
    'id': id,
    'op': op,
    if (target != null) 'target': target,
    if (op == 'set') 'value': _json(value),
    if (function != null) 'function': function,
    if (op == 'call') 'args': _json(args),
    if (failure != null) 'failure': failure,
  };
}

class Logic {
  final String source, prelude;
  final List<LogicFunction> functions;
  const Logic({
    required this.source,
    required this.prelude,
    required this.functions,
  });
  Map<String, Object?> toJson() => {
    'source': source,
    'prelude': prelude,
    'functions': functions.map((function) => function.toJson()).toList(),
  };
}

class LogicFunction {
  final String name, returns;
  final int? maxOutputBytes;
  final List<String> parameters;
  const LogicFunction({
    required this.name,
    required this.parameters,
    required this.returns,
    this.maxOutputBytes,
  });
  Map<String, Object?> toJson() => {
    'name': name,
    'parameters': parameters,
    'returns': returns,
    if (maxOutputBytes != null) 'maxOutputBytes': maxOutputBytes,
  };
}

class Style {
  // Dart uses fractional opacity; canonical IR stores whole percentage points.
  static int _opacityPercent(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(value, 'opacity', 'Expected a finite fraction from 0 to 1');
    }
    return (value * 100).round();
  }
  final int? padding,
      gap,
      width,
      height,
      maxWidth,
      borderWidth,
      radius,
      fontSize;
  final bool? fill;
  final String? color, background, borderColor, fontWeight, align;
  final double? opacity;
  const Style({
    this.padding,
    this.gap,
    this.width,
    this.height,
    this.maxWidth,
    this.fill,
    this.color,
    this.background,
    this.borderColor,
    this.borderWidth,
    this.radius,
    this.fontSize,
    this.fontWeight,
    this.align,
    this.opacity,
  });
  Map<String, Object> toJson() => {
    if (padding != null) 'padding': padding!,
    if (gap != null) 'gap': gap!,
    if (width != null) 'width': width!,
    if (height != null) 'height': height!,
    if (maxWidth != null) 'maxWidth': maxWidth!,
    if (fill != null) 'fill': fill!,
    if (color != null) 'color': color!,
    if (background != null) 'background': background!,
    if (borderColor != null) 'borderColor': borderColor!,
    if (borderWidth != null) 'borderWidth': borderWidth!,
    if (radius != null) 'radius': radius!,
    if (fontSize != null) 'fontSize': fontSize!,
    if (fontWeight != null) 'fontWeight': fontWeight!,
    if (align != null) 'align': align!,
    if (opacity != null) 'opacity': _opacityPercent(opacity!),
  };
}

enum MotionKind { fade, slide, scale }

class Motion {
  final int durationMs;
  final MotionKind kind;
  const Motion({this.durationMs = 200, this.kind = MotionKind.fade});
  Map<String, Object> toJson() => {'durationMs': durationMs, 'kind': kind.name};
}

class Text extends Node {
  Text(
    String text, {
    required super.id,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'text', props: {'text': text});
  Text.bind(
    Reference<String> text, {
    required super.id,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'text', props: {'text': text});
}

/// Numeric text, with the same canonical capability as JSON counter nodes.
class Counter extends Node {
  Counter(int value, {required super.id, super.style, super.motion, super.visibleWhen, super.enabledWhen})
    : super(type: 'counter', props: {'value': value});
  Counter.bind(Reference<int> value, {required super.id, super.style, super.motion, super.visibleWhen, super.enabledWhen})
    : super(type: 'counter', props: {'value': value});
}

class Divider extends Node {
  const Divider({required super.id, super.style, super.motion, super.visibleWhen, super.enabledWhen})
    : super(type: 'divider');
}

/// Indeterminate progress; ProgressBar is the determinate counterpart.
class Progress extends Node {
  const Progress({required super.id, super.style, super.motion, super.visibleWhen, super.enabledWhen})
    : super(type: 'progress');
}

/// Refers to a user-owned native view factory; never embeds native code strings.
class NativeView extends Node {
  NativeView(String symbol, {required super.id, super.style, super.motion, super.visibleWhen, super.enabledWhen})
    : super(type: 'native', props: {'symbol': symbol});
}

class Button extends Node {
  Button(
    String text, {
    required super.id,
    required super.action,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'button', props: {'text': text});
}

class Column extends Node {
  const Column({
    required super.id,
    super.children,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'column');
}

class Row extends Node {
  const Row({
    required super.id,
    super.children,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'row');
}

class Scroll extends Node {
  const Scroll({
    required super.id,
    super.children,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'scroll');
}

class Spacer extends Node {
  const Spacer({
    required super.id,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'spacer');
}

class Card extends Node {
  const Card({
    required super.id,
    super.children,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'card');
}

class Icon extends Node {
  Icon(
    String name, {
    required super.id,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'icon', props: {'name': name});
}

class TextField extends Node {
  TextField({
    required super.id,
    required Ref<String> value,
    String placeholder = '',
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(
         type: 'textField',
         props: {'value': value, 'placeholder': placeholder},
       );
}

class SecureField extends Node {
  SecureField({required super.id,required Ref<String> value,String placeholder='',super.style,super.motion,super.visibleWhen,super.enabledWhen})
    :super(type:'secureField',props:{'value':value,'placeholder':placeholder});
}

class Toggle extends Node {
  Toggle(
    String text, {
    required super.id,
    required Ref<bool> value,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'toggle', props: {'text': text, 'value': value});
}

class ProgressBar extends Node {
  ProgressBar(
    int value, {
    required super.id,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'progressBar', props: {'value': value});
  ProgressBar.bind(
    Ref<int> value, {
    required super.id,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'progressBar', props: {'value': value});
}

class Image extends Node {
  Image(
    String source, {
    required super.id,
    super.style,
    super.motion,
    super.visibleWhen,
    super.enabledWhen,
  }) : super(type: 'image', props: {'source': source});
}

/// Declares a versioned service contract; credentials are acquired at runtime.
class Service {
  final String baseUrl, protocol;
  final bool development;
  const Service({required this.baseUrl, this.protocol='snap.v1', this.development=false});
  Map<String,Object> toJson()=>{'baseUrl':baseUrl,'protocol':protocol,'development':development};
}

class Theme {
  final String accent,background,surface,text,muted,danger;
  final int radius,padding;
  const Theme({this.accent='#FFDD33',this.background='#F7F7F2',this.surface='#FFFFFF',this.text='#18191C',this.muted='#72757E',this.danger='#B42318',this.radius=24,this.padding=20});
  Map<String,Object> toJson()=>{'accent':accent,'background':background,'surface':surface,'text':text,'muted':muted,'danger':danger,'radius':radius,'padding':padding};
}
class Tabs extends Node {
  const Tabs({required super.id,required super.children,super.style,super.motion,TabAppearance? appearance}):super(type:'tabs',appearance:appearance);
}
class Tab extends Node {
  Tab({required super.id,required String title,required String icon,required Node child}):super(type:'tab',props:{'title':title,'icon':icon},children:[child]);
}
class Camera extends Node {
  const Camera({required super.id,super.style,super.motion}):super(type:'camera');
}
class Inbox extends Node {
  const Inbox({required super.id,super.style,super.motion}):super(type:'inbox');
}
class Stories extends Node {
  const Stories({required super.id,super.style,super.motion}):super(type:'stories');
}
class FriendMap extends Node {
  const FriendMap({required super.id,super.style,super.motion}):super(type:'friendMap');
}
class Account extends Node {
  const Account({required super.id,super.style,super.motion}):super(type:'account');
}

class Transport {
  final String baseUrl;
  final bool development;
  const Transport({required this.baseUrl, this.development = false});
  Map<String,Object?> toJson() => {'baseUrl':baseUrl,'development':development};
}
class Length {
  final Ref<String> value;
  const Length(this.value);
  Map<String,Object?> toJson() => {'length':_json(value)};
}
class Utf8Length {
  final Ref<String> value;
  const Utf8Length(this.value);
  Map<String,Object?> toJson() => {'utf8Length':_json(value)};
}
class FlowAction {
  final String id;
  final String? function;
  final String? failure;
  final List<Object> arguments;
  final List<FlowCase> cases;
  const FlowAction({required this.id,this.function,this.arguments=const[],required this.cases,this.failure});
  Map<String,Object?> toJson() => {'id':id,if(function!=null)'function':function,if(arguments.isNotEmpty)'arguments':_json(arguments),'cases':cases.map((c)=>c.toJson()).toList(),if(failure!=null)'failure':failure};
}
class FlowCase {
  final int code;
  final List<Effect> effects;
  const FlowCase({required this.code,required this.effects});
  Map<String,Object?> toJson() => {'code':code,'effects':effects.map((e)=>e.toJson()).toList()};
}
abstract class Effect {
  const Effect();
  Map<String,Object?> toJson();
}
class SetEffect extends Effect {
  final String target;
  final Object value;
  const SetEffect({required this.target,required this.value});
  @override Map<String,Object?> toJson()=>{'op':'set','target':target,'value':_json(value)};
}
class NavigateEffect extends Effect {
  final String action;
  const NavigateEffect({required this.action});
  @override Map<String,Object?> toJson()=>{'op':'navigate','action':action};
}
class InvokeEffect extends Effect {
  final String action;
  const InvokeEffect({required this.action});
  @override Map<String,Object?> toJson()=>{'op':'invoke','action':action};
}
class CancelEffect extends Effect {
  const CancelEffect();
  @override Map<String,Object?> toJson()=>{'op':'cancelRequests'};
}
class SecureEffect extends Effect {
  final String operation,key,target,failure;
  const SecureEffect({required this.operation,required this.key,required this.target,required this.failure});
  @override Map<String,Object?> toJson()=>{'op':'secure','operation':operation,'key':key,'target':target,'failure':failure};
}
class RequestEffect extends Effect {
  final String id,method,success,failure;
  final Object path;
  final Object body;
  final Ref<String>? bearer;
  final Map<String,Object> outputs;
  final String? statusTarget;
  const RequestEffect({required this.id,required this.method,required this.path,this.body=const{},this.bearer,this.outputs=const{},required this.success,required this.failure,this.statusTarget});
  @override Map<String,Object?> toJson()=>{'op':'request','id':id,'method':method,'path':_json(path),'body':_json(body),if(bearer!=null)'bearer':_json(bearer),'outputs':_json(outputs),'success':success,'failure':failure,if(statusTarget!=null)'statusTarget':statusTarget};
}

/// A typed field in one response collection; defaults apply only to missing/null fields.
class CollectionField {
  final String type;
  final Object? defaultValue;
  const CollectionField({required this.type, this.defaultValue});
  Map<String,Object?> toJson()=>{'type':type,if(defaultValue!=null)'default':defaultValue};
}
class Collection {
  final String name,key;
  final Map<String,CollectionField> fields;
  const Collection({required this.name,required this.key,required this.fields});
  Map<String,Object?> toJson()=>{'name':name,'key':key,'fields':fields.map((k,v)=>MapEntry(k,v.toJson()))};
}
class FieldRef<T> implements Reference<T> {
  final String collection,name;
  const FieldRef({required this.collection,required this.name});
}
class Repeat extends Node {
  Repeat({required super.id,required String collection,required Node child,Ref<Object>? selection,super.action})
    :super(type:'repeat',props:{'collection':collection,if(selection!=null)'selection':selection},children:[child]);
}

class ClearCollectionEffect extends Effect {
  final String target;
  const ClearCollectionEffect({required this.target});
  @override Map<String,Object?> toJson()=>{'op':'clearCollection','target':target};
}

class ResponseCollection {
  final List<String> path;
  final String mode;
  const ResponseCollection({required this.path,this.mode='replace'});
  Map<String,Object> toJson()=>{'path':path,'mode':mode};
}

class MediaState { final String name; const MediaState({required this.name}); }
class MediaRef { final String name; const MediaRef({required this.name}); }
class PhotoOptions {
  final int maxEdge,jpegQuality,maxInputBytes,maxOutputBytes,maxDecodedPixels;
  const PhotoOptions({this.maxEdge=2048,this.jpegQuality=85,this.maxInputBytes=33554432,this.maxOutputBytes=8388608,this.maxDecodedPixels=20000000});
  Map<String,Object> toJson()=>{'maxEdge':maxEdge,'jpegQuality':jpegQuality,'maxInputBytes':maxInputBytes,'maxOutputBytes':maxOutputBytes,'maxDecodedPixels':maxDecodedPixels};
}
class PickPhotoEffect extends Effect {
  final String target,source,success,cancel,failure;final PhotoOptions options;
  const PickPhotoEffect({required this.target,this.source='library',this.options=const PhotoOptions(),required this.success,required this.cancel,required this.failure});
  @override Map<String,Object?> toJson()=>{'op':'pickPhoto','target':target,'source':source,'options':options.toJson(),'success':success,'cancel':cancel,'failure':failure};
}
class ClearMediaEffect extends Effect {final String target;const ClearMediaEffect({required this.target});
  @override Map<String,Object?> toJson()=>{'op':'clearMedia','target':target};}
class MediaBody {final MediaRef source;const MediaBody(this.source);}
class MediaMetadata {
  final String operation;final MediaRef value;
  const MediaMetadata.bytes(this.value):operation='mediaBytes';
  const MediaMetadata.width(this.value):operation='mediaWidth';
  const MediaMetadata.height(this.value):operation='mediaHeight';
  const MediaMetadata.present(this.value):operation='hasMedia';
  Map<String,Object?> toJson()=>{operation:_json(value)};
}
class LocalImage extends Node {
  LocalImage({required super.id,required MediaRef source,required String accessibilityLabel,String fit='fit',required Node loading,required Node failure,super.style,super.motion,super.visibleWhen})
    :super(type:'localImage',props:{'source':source,'accessibilityLabel':accessibilityLabel,'fit':fit},children:[loading,failure]);
}
class RemoteImage extends Node {
  RemoteImage({required super.id,required Object path,required Ref<String> bearer,required String accessibilityLabel,String fit='fit',int maxBytes=8388608,int maxDecodedPixels=20000000,int maxEdge=2048,required Node loading,required Node failure,super.style,super.motion,super.visibleWhen})
    :super(type:'remoteImage',props:{'path':path,'bearer':bearer,'accessibilityLabel':accessibilityLabel,'fit':fit,'maxBytes':maxBytes,'maxDecodedPixels':maxDecodedPixels,'maxEdge':maxEdge},children:[loading,failure]);
}

class ClockEffect extends Effect {final String target,failure;const ClockEffect({required this.target,required this.failure});
  @override Map<String,Object?> toJson()=>{'op':'clock','target':target,'failure':failure};}
class ReadCollectionEffect extends Effect {
  final String collection,success,failure;final Ref<Object> key;final Map<String,String> outputs;
  const ReadCollectionEffect({required this.collection,required this.key,required this.outputs,required this.success,required this.failure});
  @override Map<String,Object?> toJson()=>{'op':'readCollection','collection':collection,'key':_json(key),'outputs':outputs,'success':success,'failure':failure};
}
class Timer {
  final String id,action;final int intervalMs;
  const Timer({required this.id,required this.intervalMs,required this.action});
  Map<String,Object> toJson()=>{'id':id,'intervalMs':intervalMs,'action':action};
}

/// Explicit C-compatible 0/1 representation of a Boolean state value.
class Flag {final Ref<bool> value;const Flag(this.value);Map<String,Object?> toJson()=>{'flag':_json(value)};}

class CameraResource {final String id;const CameraResource({required this.id});}
class PermissionEffect extends Effect {
  final String capability,statusTarget,success,failure;
  const PermissionEffect({required this.capability,required this.statusTarget,required this.success,required this.failure});
  @override Map<String,Object?> toJson()=>{'op':'permission','capability':capability,'statusTarget':statusTarget,'success':success,'failure':failure};
}
class CameraFacingEffect extends Effect {
  final String resource,facing,success,failure;
  const CameraFacingEffect({required this.resource,required this.facing,required this.success,required this.failure});
  @override Map<String,Object?> toJson()=>{'op':'cameraFacing','resource':resource,'facing':facing,'success':success,'failure':failure};
}
class CapturePhotoEffect extends Effect {
  final String resource,target,success,cancel,failure;final PhotoOptions options;
  const CapturePhotoEffect({required this.resource,required this.target,this.options=const PhotoOptions(),required this.success,required this.cancel,required this.failure});
  @override Map<String,Object?> toJson()=>{'op':'capturePhoto','resource':resource,'target':target,'options':options.toJson(),'success':success,'cancel':cancel,'failure':failure};
}
class LocationEffect extends Effect {
  final String latitudeTarget,longitudeTarget,accuracyTarget,success,cancel,failure;final int timeoutMs;
  const LocationEffect({required this.latitudeTarget,required this.longitudeTarget,required this.accuracyTarget,required this.success,required this.cancel,required this.failure,this.timeoutMs=15000});
  @override Map<String,Object?> toJson()=>{'op':'location','latitudeTarget':latitudeTarget,'longitudeTarget':longitudeTarget,'accuracyTarget':accuracyTarget,'success':success,'cancel':cancel,'failure':failure,'timeoutMs':timeoutMs};
}
class MapRegion {
  final int latitudeE6,longitudeE6,latitudeSpanE6,longitudeSpanE6;
  const MapRegion({required this.latitudeE6,required this.longitudeE6,required this.latitudeSpanE6,required this.longitudeSpanE6});
  Map<String,Object> toJson()=>{'latitudeE6':latitudeE6,'longitudeE6':longitudeE6,'latitudeSpanE6':latitudeSpanE6,'longitudeSpanE6':longitudeSpanE6};
}
class MapConfig {
  final String androidModule,styleUrl,attribution;
  const MapConfig({required this.androidModule,required this.styleUrl,required this.attribution});
  Map<String,Object> toJson()=>{'androidModule':androidModule,'styleUrl':styleUrl,'attribution':attribution};
}
class CameraPreview extends Node {
  CameraPreview({required super.id,required String resource,required Ref<bool> active,required Ref<bool> ready,required String accessibilityLabel,String fit='fill',required Node loading,required Node failure,super.style})
    :super(type:'cameraPreview',props:{'resource':resource,'active':active,'ready':ready,'accessibilityLabel':accessibilityLabel,'fit':fit},children:[loading,failure]);
}
class NativeMap extends Node {
  NativeMap({required super.id,required String collection,required String latitudeField,required String longitudeField,required String titleField,required MapRegion region,Ref<Object>? selection,super.action,required Node annotation,required Node loading,required Node failure,super.style})
    :super(type:'nativeMap',props:{'collection':collection,'latitudeField':latitudeField,'longitudeField':longitudeField,'titleField':titleField,'region':region.toJson(),if(selection!=null)'selection':selection},children:[annotation,loading,failure]);
}

/// Canonical operation scalars. `int` is signed 32-bit on both native targets.
enum NativeScalar { string, int, bool }
enum NativeExecution { caller, main, worker }

class NativeParameter {
  final String name;
  final NativeScalar type;
  const NativeParameter(this.name, this.type);
  Map<String,Object> toJson() => {'name':name,'type':type.name};
}

/// Structured SDK values never contain executable native source.
abstract class NativeValue {
  const NativeValue();
  Map<String,Object?> toJson();
}
class NativeRef extends NativeValue {
  final String name;
  const NativeRef(this.name);
  @override
  Map<String,Object?> toJson() => {'ref':name};
}
class NativeLiteral extends NativeValue {
  final Object? value;
  const NativeLiteral(this.value);
  @override
  Map<String,Object?> toJson() {
    var remaining = 4096;
    Object? encode(Object? item, int depth) {
      if (--remaining < 0 || depth > 16) {
        throw ArgumentError('Native literal exceeds size or nesting limit');
      }
      if (item == null || item is String || item is bool || item is int) return item;
      if (item is double && item.isFinite) return item;
      if (item is List) return [for (final child in item) encode(child, depth + 1)];
      if (item is Map) {
        final result = <String,Object?>{};
        for (final entry in item.entries) {
          if (entry.key is! String) throw ArgumentError('Native dictionary keys must be strings');
          encode(entry.key, depth + 1);
          result[entry.key as String] = encode(entry.value, depth + 1);
        }
        return result;
      }
      throw ArgumentError('Native literals require finite scalar or collection values');
    }
    return {'literal':encode(value, 0)};
  }
}
/// A concrete Android array type, checked against the SDK parameter type.
class NativeArray extends NativeValue {
  final List<Object?> values;
  final String type;
  const NativeArray(this.values, {required this.type});
  @override
  Map<String,Object?> toJson() => {
    'array': NativeLiteral(values).toJson()['literal'], 'type': type,
  };
}
class NativeNull extends NativeValue {
  final String type;
  const NativeNull(this.type);
  @override
  Map<String,Object?> toJson() => {'null':type};
}
/// An Android class token such as Uri.class, validated by the native compiler.
class NativeClass extends NativeValue {
  final String type;
  const NativeClass(this.type);
  @override Map<String,Object?> toJson() => {'class':type};
}
abstract class NativeStep {
  const NativeStep();
  Map<String,Object?> toJson();
}
class NativeTupleElement extends NativeStep {
  final NativeRef tuple;
  final int index;
  final String bind;
  const NativeTupleElement(this.tuple, {required this.index, required this.bind});
  @override Map<String,Object?> toJson() => {
    'project': {'ref':tuple.name, 'index':index}, 'bind':bind,
  };
}
class NativeUnwrap extends NativeStep {
  final NativeRef value;
  final String bind, message;
  const NativeUnwrap(this.value, {required this.bind, required this.message});
  @override Map<String,Object?> toJson() => {
    'unwrap':value.toJson(), 'bind':bind, 'message':message,
  };
}
class NativeCall extends NativeStep {
  final String id;
  final String? scope, bind, constructedType, variant;
  final NativeRef? receiver;
  final List<NativeValue> arguments;
  final NativeValue? set;
  final List<String>? typeArguments;
  const NativeCall(this.id, {this.scope, this.bind, this.receiver,
    this.arguments=const [], this.set, this.typeArguments, this.constructedType, this.variant});
  Map<String,Object?> toJson() => {
    'id':id, if(scope!=null)'scope':scope, if(bind!=null)'bind':bind,
    if(receiver!=null)'receiver':receiver!.toJson(),
    if(arguments.isNotEmpty)'arguments':arguments.map((v)=>v.toJson()).toList(),
    if(set!=null)'set':set!.toJson(),
    if(typeArguments!=null)'typeArguments':typeArguments,
    if(constructedType!=null)'constructedType':constructedType,
    if(variant!=null)'variant':variant,
  };
}
class NativeImplementation {
  final List<NativeStep> steps;
  final NativeRef result;
  final List<int>? iosVersion;
  final String? androidSdkSha256;
  final int? androidMinSdk, androidCompileSdk;
  const NativeImplementation({required this.steps, required this.result, this.iosVersion, this.androidSdkSha256, this.androidMinSdk, this.androidCompileSdk});
  Map<String,Object?> toJson() => {'steps':steps.map((s)=>s.toJson()).toList(),
    'return':result.toJson(),if(iosVersion!=null)'iosVersion':iosVersion,
    if(androidSdkSha256!=null)'androidSdkSha256':androidSdkSha256,
    if(androidMinSdk!=null)'androidMinSdk':androidMinSdk,
    if(androidCompileSdk!=null)'androidCompileSdk':androidCompileSdk};
}
/// Author with buildOperation(); evaluated only with explicit --evaluate-dart.
/// This describes a compiler input, not an operation executed by Dart in an app.
class NativeOperation {
  final String name;
  final List<NativeParameter> parameters;
  final NativeScalar result;
  final bool throwsErrors;
  /// Completion may suspend; execution independently selects the native context.
  final bool suspends;
  final NativeExecution execution;
  final NativeImplementation ios, android;
  const NativeOperation({required this.name, this.parameters=const [],
    required this.result, this.throwsErrors=false, this.suspends=false, this.execution=NativeExecution.caller, required this.ios, required this.android});
  Map<String,Object?> toJson() => {'name':name,
    'parameters':parameters.map((p)=>p.toJson()).toList(), 'result':result.name,
    'throws':throwsErrors,'suspends':suspends,'execution':execution.name,'implementations':{'ios':ios.toJson(),'android':android.toJson()}};
}

/// Call a declared main/worker native operation, then dispatch a completion flow.
/// Terminal shared DC Dart call, with typed state assignment and continuations.
class LogicCallEffect extends Effect {
  final String function, target, success, failure;
  final List<Object> arguments;
  const LogicCallEffect({required this.function, this.arguments=const [],
    required this.target, required this.success, required this.failure});
  @override Map<String,Object?> toJson() => {'op':'logicCall','function':function,
    'arguments':arguments.map(_json).toList(),'target':target,'success':success,'failure':failure};
}

class NativeOperationEffect extends Effect {
  final String operation, target, success, failure;
  final List<Object> arguments;
  const NativeOperationEffect({required this.operation, this.arguments=const [],
    required this.target, required this.success, required this.failure});
  @override Map<String,Object?> toJson() => {'op':'nativeOperation',
    'operation':operation,'arguments':arguments.map(_json).toList(),
    'target':target,'success':success,'failure':failure};
}
