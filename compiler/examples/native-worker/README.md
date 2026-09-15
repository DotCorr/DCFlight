# Native worker example

`app.dart` defines one screen and one shared operation contract. Pressing
Generate identifier executes Foundation UUID on iOS or java.util.UUID on
Android off the main thread, then publishes the identifier and shared status
on the main thread. Both native implementations are selected at compile time.

Supply `sdk.sqlite` containing the Foundation UUID constructor and uuidString
property plus Android java.util.UUID randomUUID/toString entries. The SDK
catalog and its verified source files are development inputs. Evaluate the
Dart authoring with the dcflight CLI and compile both native targets using the
normal compiler workflow. The emitted projects build with Xcode and Gradle.

See `docs/native-worker-operations.md` for cancellation and execution semantics.
The example verifies the worker path; UUID generation is not a performance
benchmark or proof of complete asynchronous application logic.
