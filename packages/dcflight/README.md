
# dcflight

`dcflight` is the core runtime package for DCFlight.

## Supported Architecture

The supported bridge model is now strict:

- iOS renderer calls go through FFI
- Android renderer calls go through JNI
- Native events are sent back through direct callbacks
- Screen and safe-area updates are delivered through FFI/JNI callbacks

The package no longer treats Flutter-widget embedding as part of the supported runtime architecture. `WidgetToDCFAdaptor` remains only as a disabled compatibility surface that throws if used.

## Rendering Model

```text
Dart component tree
  -> reactive engine
  -> native bridge abstraction
  -> FFI / JNI
  -> native views
```

## Guarantees

- Native view rendering only
- No platform-view dependency
- No method-channel renderer path in the active runtime
- Hot restart and cleanup coordinated through native bridge wrappers

## Core Responsibilities

- Bridge setup and lifecycle
- Component tree synchronization
- Reactive signal-based updates
- Event propagation from native to Dart
- Layout synchronization with Yoga

## Important Note

Older documentation and experiments in this repository described mixed bridge approaches and Flutter-widget embedding. Those are not the canonical architecture anymore.

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://coff.ee/squirelboy360)  

[**buy_me_a_coffee: https://coff.ee/squirelboy360**](https://coff.ee/squirelboy360)

