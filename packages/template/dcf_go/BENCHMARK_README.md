# DCFlight Performance Benchmark

This benchmark tests DCFlight's render performance and compares it against React benchmarks.

## Running the Benchmark

### Option 1: Run the benchmark app directly

```bash
cd packages/template/dcf_go
flutter run -d <device-id> lib/benchmark_app.dart
```

This will:
1. Run the benchmark tests
2. Display results in the console
3. Show results in the app UI

### Option 2: Run benchmark from your main app

```dart
import 'benchmark.dart';

// In your app initialization
final results = await PerformanceBenchmark.runBenchmark();
print('Results: $results');
```

## What Gets Tested

1. **Initial render (1000 nodes)**: Measures time to create and render 1000 components
2. **Update (100 nodes)**: Measures time to update 100 components
3. **Initial render (500 nodes)**: Measures time to create and render 500 components
4. **Keyed list (1000 items)**: Measures reconciliation performance for keyed lists

## Expected Results

Based on React benchmarks:
- **React**: ~16ms for 1000 nodes initial render
- **React**: ~8ms for 100 nodes update

**DCFlight target**: 2x faster than React (8ms for 1000 nodes, 4ms for 100 nodes)

## Interpreting Results

The benchmark runs 10 iterations, removes outliers, and calculates the average. Results show:
- **Actual render time** in milliseconds
- **Speedup factor** compared to React (2x = twice as fast)

## Notes

- The benchmark measures **full render time** including native bridge calls
- First 2 runs are excluded as warmup
- Results may vary based on device performance
- For accurate comparisons, run on the same device multiple times

