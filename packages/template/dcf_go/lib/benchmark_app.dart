import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';
import 'benchmark.dart';

void main() async {
  DCFLogger.setLevel(DCFLogLevel.info);
  DCFLogger.info('Starting Performance Benchmark App...', 'Benchmark');
  
  // Initialize DCFlight first (this initializes the engine)
  await DCFlight.go(app: BenchmarkApp());
}

class BenchmarkApp extends DCFStatefulComponent {
  final VoidCallback? onBack;
  
  BenchmarkApp({this.onBack});
  
  @override
  DCFComponentNode render() {
    final resultsState = useState<Map<String, dynamic>?>(null);
    final benchmarkRunning = useState<bool>(false);
    
    // Run benchmark once when component mounts
    if (!benchmarkRunning.state && resultsState.state == null) {
      benchmarkRunning.setState(true);
      _runBenchmark().then((results) {
        resultsState.setState(results);
        benchmarkRunning.setState(false);
      });
    }
    
    if (resultsState.state == null) {
      return DCFView(
        layout: DCFLayout(
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
      results: resultsState.state!,
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

