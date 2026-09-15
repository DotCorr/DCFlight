# dcflight compiler

This package implements the user's replacement architecture. The parent repository's runtime/bridge/component conventions describe legacy code and MUST NOT be used here. Existing license requirements still apply.

- Development-time only. Emit ordinary native source and toolchain projects.
- Never ship a dcflight library, interpreter, Dart VM, JS bridge, renderer, or registry.
- JSON and the restricted Dart DSL are frontends, never the canonical type system.
- Validate all authoring input before code generation. Unsupported semantics must fail.
- Registry templates are reviewed compiler code; SDK inventories are untrusted data and never automatically executable mappings.
- Stable explicit node IDs determine native symbols and source file identity.
- Generated files are editable, but conflicting edits must stop synchronization. User-owned files are never overwritten or deleted.
- Test with `python3 -m unittest discover -s tests -v`. Native verification is `python3 tools/verify_native.py --ios` or the documented Android SDK/toolchain options.
- DC Dart changes require intentional tests, versioning and release. Shared logic uses released DC Dart 0.1.1+ as a development tool only. Native objects must pass symbol and final-link audits.
