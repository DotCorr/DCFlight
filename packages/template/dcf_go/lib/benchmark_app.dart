import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';
import 'benchmark.dart';


class BenchmarkApp extends DCFStatefulComponent {
  final VoidCallback? onBack;
  bool _benchmarkStarted = false;
  Map<String, dynamic>? _results;
  
  BenchmarkApp({this.onBack});
  
  @override
  void componentDidMount() {
    super.componentDidMount();
    // Start benchmark AFTER component is mounted and rendered
    // This ensures the UI is visible and responsive
    if (!_benchmarkStarted) {
      _benchmarkStarted = true;
      // Use a small delay to ensure native view is fully created
      Future.delayed(Duration(milliseconds: 200), () async {
        try {
          final results = await _runBenchmark();
          _results = results;
          // Trigger a re-render to show results
          scheduleUpdate();
        } catch (e) {
          print('❌ Benchmark error: $e');
          _benchmarkStarted = false; // Allow retry on error
        }
      });
    }
  }
  
  @override
  DCFComponentNode render() {
    if (_results == null) {
      return DCFView(
        layout: DCFLayout(
          flex:1,
          flexDirection: DCFFlexDirection.column,
          justifyContent: DCFJustifyContent.center,
          alignItems: DCFAlign.center,
        ),
        children: [
          DCFText(
            content: 'Running benchmark...',
            textProps: DCFTextProps(fontSize: 18),
          ),
        ],
      );
    }
    
    return BenchmarkResultsApp(
      results: _results!,
      onBack: onBack,
    );
  }
  
  Future<Map<String, dynamic>> _runBenchmark() async {
    // Run benchmark after engine is initialized
    final results = await PerformanceBenchmark.runBenchmark();
    
    // Print final results
    print('\n✅ Benchmark Complete!\n');
    print('📊 Final Results:');
    print('   Initial render (1000 nodes): ${results['initialRender_1000'].toStringAsFixed(2)}ms');
    print('   Update (100 nodes): ${results['update_100'].toStringAsFixed(2)}ms');
    
    final comparison = results['comparison'] as Map<String, dynamic>;
    print('\n🏆 vs React:');
    print('   Initial render: ${comparison['speedup_initial'].toStringAsFixed(2)}x ${comparison['speedup_initial'] > 1 ? "faster" : "slower"}');
    print('   Update: ${comparison['speedup_update'].toStringAsFixed(2)}x ${comparison['speedup_update'] > 1 ? "faster" : "slower"}');
    
    return results;
  }
}

class BenchmarkResultsApp extends DCFStatefulComponent {
  final Map<String, dynamic> results;
  final VoidCallback? onBack;
  
  BenchmarkResultsApp({required this.results, this.onBack});
  
  @override
  DCFComponentNode render() {
    final comparison = results['comparison'] as Map<String, dynamic>;
    final initialRender = results['initialRender_1000'] as double;
    final update = results['update_100'] as double;
    final speedupInitial = comparison['speedup_initial'] as double;
    final speedupUpdate = comparison['speedup_update'] as double;
    
    return DCFView(
      layout: DCFLayout(
        padding: 20,
        flex:1,
        flexDirection: DCFFlexDirection.column,
        justifyContent: DCFJustifyContent.center,
        alignItems: DCFAlign.center,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFTheme.backgroundColor,
      ),
        children: [
          DCFText(
            content: 'Performance Benchmark Results',
            textProps: DCFTextProps(
              fontSize: 24,
              fontWeight: DCFFontWeight.bold,
            ),
          ),
          DCFView(layout: DCFLayout(height: 20)),
          DCFText(
            content: 'Initial render (1000 nodes):',
            textProps: DCFTextProps(fontSize: 18),
          ),
          DCFText(
            content: '${initialRender.toStringAsFixed(2)}ms',
            textProps: DCFTextProps(
              fontSize: 20,
              fontWeight: DCFFontWeight.bold,
            ),
            styleSheet: DCFStyleSheet(
              primaryColor: speedupInitial > 1 ? DCFTheme.accentColor : DCFTheme.textColor,
            ),
          ),
          DCFView(layout: DCFLayout(height: 10)),
          DCFText(
            content: 'Update (100 nodes):',
            textProps: DCFTextProps(fontSize: 18),
          ),
          DCFText(
            content: '${update.toStringAsFixed(2)}ms',
            textProps: DCFTextProps(
              fontSize: 20,
              fontWeight: DCFFontWeight.bold,
            ),
            styleSheet: DCFStyleSheet(
              primaryColor: speedupUpdate > 1 ? DCFTheme.accentColor : DCFTheme.textColor,
            ),
          ),
          DCFView(layout: DCFLayout(height: 20)),
          DCFText(
            content: 'vs React:',
            textProps: DCFTextProps(
              fontSize: 18,
              fontWeight: DCFFontWeight.bold,
            ),
          ),
          DCFText(
            content: '${speedupInitial.toStringAsFixed(2)}x ${speedupInitial > 1 ? "faster" : "slower"} (initial)',
            textProps: DCFTextProps(fontSize: 16),
          ),
          DCFText(
            content: '${speedupUpdate.toStringAsFixed(2)}x ${speedupUpdate > 1 ? "faster" : "slower"} (update)',
            textProps: DCFTextProps(fontSize: 16),
          ),
          DCFView(layout: DCFLayout(height: 30)),
          DCFButton(
            buttonProps: DCFButtonProps(title: "Back"),
            onPress: (data) {
              onBack?.call();
            },
          ),
        ],
    );
  }
}

