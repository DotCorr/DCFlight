# Native typography verification

Run `tools/verify_android_typography.py` with `--sdk`, `--java-home`, `--gradle`,
`--serial`, a fresh `--work` directory, and `--report`. It generates a normal
Compose project and checks the emitted authored-size style. A native
instrumentation test measures the same two-line 40sp heading using inherited
Material line height and corrected natural line metrics on the selected device.

The harness installs only its dedicated `com.dotcorr.typographyprobe` app and
test package. It performs no UI gestures. Build, installation and measurement
logs remain in the supplied work directory. The JSON report records device
density/font scale, line baseline spacing, height and fixture/source hashes.

The correction applies to authored Text/counter, Button labels, text and secure
fields, and Toggle labels. Text without an explicit fontSize keeps native theme
defaults. Font family, weight and foreground values remain available through
the existing style merge. The fix clears inherited lineHeight on LocalTextStyle
itself, since Text's unspecified lineHeight argument otherwise preserves it.

This is native layout measurement, not screenshot or end-to-end acceptance.
Authored font sizes honor native text-size preferences on both platforms.
SwiftUI uses ScaledMetric relative to body; Android uses sp and native density
conversion. Native scaling tests do not certify all screens at every supported
accessibility size.
