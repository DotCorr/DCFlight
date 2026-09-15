# dcflight

This is the new dcflight project. It is separate from the old DCFlight runtime framework.

The compiler implementation is in [compiler/](compiler/README.md).

The architecture is development-time only: authoring, compilation, native API registry, source synchronization and AI tooling. Generated applications are ordinary native projects with no dcflight runtime, renderer, Dart VM or introduced JavaScript engine. DC Dart is the chosen shared logic language, compiled ahead of time.

This folder contains a copy of the current new implementation. Active work in the original main task has not been redirected or removed by this side conversation.
