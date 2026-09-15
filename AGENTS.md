# New dcflight project

This is a new project and vision, separate from the legacy DCFlight runtime repository. Never import the legacy runtime architecture into this project.

- Development-time compiler, codebase synchronizer, native API registry and AI tooling only.
- Generated apps ship no dcflight runtime, Dart VM, JavaScript bridge/engine introduced by dcflight, renderer or framework dispatch layer.
- DC Dart is the shared logic language and must compile ahead of time. Intentional dependency changes need tests, versioning and a release.
- Implement iOS and Android in parallel with scalable SDK-derived coverage. Indexed symbols are not implemented or verified capabilities.
- Preserve user-owned source and reject destructive generation conflicts.
- Read `compiler/AGENTS.md` for implementation conventions.
