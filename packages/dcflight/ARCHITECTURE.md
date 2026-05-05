# DCFlight Architecture

## Canonical Runtime

DCFlight uses Flutter for Dart runtime support, then diverges into a native renderer immediately.

```text
Dart components
  -> engine / reconciliation layer
  -> bridge interface
  -> iOS FFI or Android JNI
  -> native view tree
```

## Bridge Rules

The framework is standardized around these rules:

1. Rendering operations go through FFI on iOS and JNI on Android.
2. Native events return to Dart through direct callback registration.
3. Screen dimension changes and safe-area updates are reported through FFI/JNI callbacks.
4. Mixed platform-channel rendering paths are not part of the supported runtime.

## Engine Behavior

DCFlight uses a reactive engine with two practical update shapes:

- Prop-level signal changes update native nodes directly when possible.
- Structural changes trigger tree reconciliation and native view synchronization.

This keeps the developer model declarative while preserving direct native ownership.

## Native Ownership

### iOS

- `DCFAppDelegate` boots the Flutter engine and diverges directly into native UI.
- `DCFlightNative.swift` exposes the renderer to Dart via FFI.
- `DCFScreenUtilities.swift` reports dimensions and safe-area changes through FFI callbacks.

### Android

- `DCFFlutterActivity` diverges to the native UI directly.
- `DCFlightJni.kt` and `DCFlightNative.kt` expose the renderer to Dart through JNI.
- `DCFScreenUtilities.kt` reports dimensions through JNI callbacks.

## Removed Runtime Surface

The framework previously contained a Flutter-widget embedding path. That surface depended on platform channels and a secondary Flutter view/controller. It is no longer part of the supported runtime and has been removed from active registration and initialization.

## Documentation Contract

When code and docs disagree, this file is canonical for bridge architecture. Any document that describes method-channel-based rendering or Flutter-widget embedding as part of the runtime is outdated.
    final doubled = computed(() => count() * 2);
    final greeting = computed(() => "Hello, ${name()}!");
    
    return DCFView(
      children: [
        // Direct updates
        DCFText(content: () => greeting()),
        DCFText(content: () => "Count: ${count()} (x2 = ${doubled()})"),
        
        // Event handlers
        DCFButton(
          onPress: () => count.set(count() + 1),
          child: DCFText(content: "Increment"),
        ),
        
        // Conditional rendering (reconciliation)
        if (showDetails())
          DetailsPanel(),
        
        DCFButton(
          onPress: () => showDetails.set(!showDetails()),
          child: DCFText(
            content: () => showDetails() ? "Hide" : "Show",
          ),
        ),
      ],
    );
  }
}
```

---

**The Rule:** Use `signal()` for everything. Engine handles the rest.
