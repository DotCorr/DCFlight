// Run from package root (dcf_platform_view): dart run scripts/fix_package_config.dart
// Replaces relative rootUri for dcf_platform_view with absolute file URI so the analyzer finds the package.
import 'dart:convert';
import 'dart:io';

void main() {
  final packageRoot = Directory.current.absolute.path;
  final packageConfigPath = File('example/.dart_tool/package_config.json');
  if (!packageConfigPath.existsSync()) {
    print('Run from package root (dcf_platform_view) after: cd example && flutter pub get');
    exit(1);
  }
  final uri = 'file://${packageRoot.replaceAll(r'\', '/')}';
  final content = packageConfigPath.readAsStringSync();
  final decoded = jsonDecode(content) as Map<String, dynamic>;
  final packages = decoded['packages'] as List<dynamic>;
  for (final p in packages) {
    final m = p as Map<String, dynamic>;
    if (m['name'] == 'dcf_platform_view') {
      m['rootUri'] = uri;
      break;
    }
  }
  packageConfigPath.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(decoded));
  print('Updated dcf_platform_view rootUri to $uri');
}
