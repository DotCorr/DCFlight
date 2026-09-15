# Dart as a first-class authoring API

The Dart authoring package describes native applications during development.
It provides named components, typed state references, styling and transitions.
The result enters the same canonical validation and native generators as JSON.
Neither the package nor its Dart SDK is linked into the application.

There are two deliberately separate entry points:

- The existing restricted loader reads `const app = App(...)` without executing
  Dart. It remains suitable for untrusted declarations and AI tool input.
- `load_evaluated(path, dart=...)` explicitly executes a trusted Dart file's
  top-level `App buildApp()`. Developers can use normal helpers, collections,
  loops, imports and package composition. This is local code execution with the
  user's permissions, not a sandbox. It is never automatically selected by the
  restricted loader or MCP.

A minimal composition:

```dart
import 'package:dcflight_authoring/dcflight.dart';

Node friend(String id, String name) => Text(name, id: 'friend_$id');

App buildApp() {
  final names = ['Ada', 'Lin', 'Sam'];
  return App(
    id: 'com.example.friends',
    name: 'Friends',
    root: Column(id: 'friends', children: [
      for (var i = 0; i < names.length; i++) friend('$i', names[i]),
    ]),
  );
}
```

Explicit node identities are still required. Use domain identities rather than
list indices when user data can reorder; indices in the small static example
are sufficient because those names are fixed authoring data.

## Components and shared attributes

`Text`, `Button`, `Column`, `Row`, `Scroll`, `Spacer`, `Card`, `Icon`, `TextField`,
`Toggle`, `ProgressBar` and `Image` are developer-facing constructors. `Node`
remains available for direct registry capabilities and compatibility with
existing code. `Scroll` supports one native content child; group multiple
children in a Column. Progress values use integer percentages from 0 to 100.
Images use the canonical source contract, including HTTPS URLs and `asset:name`.

String literals use `Text('Hello', id: 'greeting')`. A state-bound label uses
`Text.bind(const Ref<String>(name: 'title'), id: 'title')`. TextField accepts
`Ref<String>` and Toggle accepts `Ref<bool>`. ProgressBar has literal and bound
constructors. This catches mismatched developer arguments through Dart analysis;
canonical validation additionally checks referenced state names and semantics.

Every component accepts `style`, `motion` and `visibleWhen`:

```dart
Text(
  'Camera',
  id: 'title',
  style: const Style(fontSize: 28, fontWeight: 'bold', color: '#111111'),
  motion: const Motion(durationMs: 220, kind: MotionKind.fade),
  visibleWhen: const Ref<bool>(name: 'showTitle'),
)
```

Style serializes only explicitly supplied values: padding, gap, width, height,
maxWidth, fill, color, background, borderColor, borderWidth, radius, fontSize,
fontWeight, align and opacity. Motion serializes duration and fade/slide/scale.
`fontSize` is the default-scale logical font size and follows the user's native
text-size preference on iOS and Android. Geometry such as padding and fixed
frames is not automatically enlarged; author layouts that can wrap and scroll.
The platform generators determine supported native behavior; Dart constructors
do not silently emulate an unsupported native effect.

## Authoring versus shared application logic

Normal Dart helpers above run only to construct the application document. Their
closures are not runtime event handlers. Business logic remains the separately
compiled DC Dart module, referenced with `Logic` and invoked by `Action.call`.
The convenient `Action.set` and `Action.toggle` constructors retain their existing
canonical operations. `Ref(name: ...)`, raw Node, Action and App constructors
remain backward compatible.

## Evaluation and packaging

The evaluator builds a temporary package configuration pointing at the authoring
API. If the developer's project already has `.dart_tool/package_config.json`,
its dependencies remain available. Missing packages are not downloaded and no
pubspec commands run implicitly. A typed temporary runner calls `buildApp()` and
writes JSON on a separate file channel; developer stdout cannot corrupt it.
Failures and timeouts return explicit diagnostics. The returned document still
needs canonical `lower(...)` validation before generation.

`authoring/lib/dcflight.dart` is the single maintained API source. Wheel builds
copy it into package resources through the build hook; runtime authoring discovery
uses those resources when a source checkout is unavailable. Regeneration uses a
Dart SDK on the development machine only. Verify with:

```
python3 -m unittest discover -s tests -p test_evaluated_frontend.py -v
python3 tools/verify_dart_authoring_package.py path/to/compiler.whl --dart /path/to/dart
```

The wheel test evaluates ordinary Dart composition from the installed package,
compares the bundled API to its canonical source, emits both native platforms,
and audits the generated source for prohibited runtime dependencies.
