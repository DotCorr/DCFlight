# Shared native navigation appearance

Routed applications can author colors on individual native navigation hosts. This is separate from the legacy social-screen `Theme`. The same typed Dart authoring and JSON document lower to frozen canonical appearance values.

```dart
NavigationStack(
  id: 'homeStack', initialRoute: 'home',
  appearance: const NavigationAppearance(accent: '#A73522', surface: '#FFF4E8'),
)
Tabs(
  id: 'mainTabs',
  appearance: const TabAppearance(
    selectedForeground: '#A73522',
    unselectedForeground: '#4E5965',
    surface: '#FFF4E8',
  ),
  children: [/* authored Tab nodes */],
)
```

JSON uses the optional node field `appearance`. Stack appearance accepts only `accent` and `surface`. Tab host appearance accepts only `selectedForeground`, `unselectedForeground` and `surface`. Colors must be literal `#RRGGBB` or `#RRGGBBAA` strings; omitted fields retain native defaults. Appearance on a tab item, another UI primitive, or an incompatible canonical host is rejected. Generic layout styles and motion on routed navigation hosts remain rejected.

Stack accent maps to native SwiftUI tint and Compose navigation/action icon colors; stack surface maps to navigation bar background, including pushed destinations and presentations owned by that stack. It does not specify title font, title color or route-content background. Tab foregrounds apply to both label and icon. Tab surface controls the native bar background; platform selection indicators, safe areas, fonts, geometry and transitions retain native behavior.

Styled iOS tabs use a generated app-owned `UITabBarController` with stable-ID `UIHostingController` children. The app updates retained roots and copied SwiftUI environment values rather than rebuilding controllers, and native selection changes write the SwiftUI selection binding. Each controller configures only its own bar appearance. There is no global UIKit appearance proxy or hierarchy introspection. Tabs without appearance retain their existing SwiftUI `TabView` generation. Android keeps Compose `NavigationBar`, `NavigationBarItem` and Navigation `NavHost`.

These are ordinary generated native source files, with existing generated/user-owned conflict boundaries. No dcflight runtime, registry, Dart VM or custom renderer ships with the app. Native control appearance does not promise identical platform geometry. The `examples/navigation-appearance/app.dart` fixture exercises matching Home, Detail and Profile states, shared text and root reset from one authoring source.

## Native design and exact-color fixtures

Appearance configures the native control. The platform retains authority over its materials and appearance behavior; native-adaptive styling does not guarantee exact pixels across OS versions. In particular, iOS 26 Liquid Glass can render tab colors differently. dcflight never changes the application design mode because a tab is styled, including empty or mixed styled/unstyled hosts.

The solid-color example makes an explicit **whole-application** iOS compatibility choice through the existing typed authoring API:

```dart
nativeConfiguration: const NativeConfiguration(
  ios: IOSConfiguration(infoPlist: {
    'UIDesignRequiresCompatibility': PlistValue.boolean(true),
  }),
),
```

This is not a per-tab preference. Remove it (or explicitly set false) to use the current native design. It is an Apple compatibility facility, not a durable cross-version exact-rendering guarantee. JSON uses the same nativeConfiguration.ios.infoPlist typed boolean value. No implicit default or metadata injection exists. See [Apple’s property-list reference](https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility) and [UIKit new design guidance](https://developer.apple.com/videos/play/wwdc2025/284/).
