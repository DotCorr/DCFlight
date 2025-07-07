import 'dart:math';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final resultHook = useState<String>('No calculation yet');
    final isCalculatingHook = useState<bool>(false);
    final counterHook = useState<int>(0);
    final timingHook = useState<String>('');

    // This timer simulates other UI updates happening during heavy calculation
    useEffect(() {
      final timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        if (!isCalculatingHook.state) return;
        counterHook.setState(counterHook.state + 1);
      });
      return () => timer.cancel();
    }, dependencies: [isCalculatingHook.state]);

    return DCFScrollView(
      layout: LayoutProps(
        padding: 20,
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(backgroundColor: Colors.white),
      children: [
        DCFText(
          content: 'DCFlight VDom Concurrency Test',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
            color: Colors.black,
            textAlign: 'center',
          ),
        ),

        DCFView(layout: LayoutProps(height: 20), children: []),

        DCFText(
          content: 'This calculation would freeze other frameworks:',
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.grey,
            textAlign: 'center',
          ),
        ),

        DCFView(layout: LayoutProps(height: 30), children: []),

        DCFButton(
          layout: LayoutProps(padding: 15, height: 100),
          styleSheet: StyleSheet(
            borderRadius: 8,
            backgroundColor:
                isCalculatingHook.state ? Colors.grey : Colors.blue,
          ),
          // disabled: isCalculatingHook.state,
          onPress: (_) async {
            developer.log('🚀 Starting heavy calculation...');
            final startTime = DateTime.now();

            isCalculatingHook.setState(true);
            resultHook.setState('Calculating...');
            counterHook.setState(0);
            timingHook.setState(
              'Started at: ${startTime.toString().substring(11, 19)}',
            );

            // Give UI a chance to update before starting calculation
            await Future.delayed(Duration(milliseconds: 100));

            // This is BLOCKING math that would freeze other UIs
            // But DCFlight VDom should handle it smoothly
            developer.log('💪 Performing blocking calculation...');
            double result = performBlockingCalculation();

            final endTime = DateTime.now();
            final duration = endTime.difference(startTime);
            developer.log(
              '✅ Calculation completed in ${duration.inMilliseconds}ms',
            );

            resultHook.setState('Result: ${result.toStringAsFixed(6)}');
            timingHook.setState('Completed in: ${duration.inMilliseconds}ms');
            isCalculatingHook.setState(false);
          },

          buttonProps: DCFButtonProps(
            title:
                isCalculatingHook.state
                    ? 'Calculating...'
                    : 'Start Heavy Calculation',
          ),
        ),

        DCFView(layout: LayoutProps(height: 30), children: []),

        DCFText(
          content: resultHook.state,
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.black,
            textAlign: 'center',
          ),
        ),

        if (timingHook.state.isNotEmpty) ...[
          DCFView(layout: LayoutProps(height: 10), children: []),
          DCFText(
            content: timingHook.state,
            textProps: DCFTextProps(
              fontSize: 12,
              color: Colors.blue,
              textAlign: 'center',
            ),
          ),
        ],

        DCFView(layout: LayoutProps(height: 20), children: []),

        if (isCalculatingHook.state) ...[
          DCFText(
            content:
                'UI Counter (proving UI is not frozen): ${counterHook.state}',
            textProps: DCFTextProps(
              fontSize: 14,
              color: Colors.green,
              textAlign: 'center',
            ),
          ),

          DCFView(layout: LayoutProps(height: 10), children: []),

          DCFSpinner(
            layout: LayoutProps(height: 30, width: 30),
            animating: true,
            style: DCFSpinnerStyle.medium,
            color: Colors.blue,
          ),
        ],

        DCFView(layout: LayoutProps(height: 40), children: []),

        DCFScrollView(
          layout: LayoutProps(padding: 15, height: "30%"),
          styleSheet: StyleSheet(
            borderRadius: 8,
            backgroundColor: Colors.grey.shade200,
          ),
          children: [
            DCFText(
              content: 'Test Instructions:',
              textProps: DCFTextProps(
                fontSize: 14,
                fontWeight: DCFFontWeight.bold,
                color: Colors.black,
              ),
            ),
            DCFText(
              content: '1. Tap the button to start heavy calculation',
              textProps: DCFTextProps(fontSize: 12, color: Colors.black),
            ),
            DCFText(
              content: '2. Watch the counter - it should keep updating',
              textProps: DCFTextProps(fontSize: 12, color: Colors.black),
            ),
            DCFText(
              content: '3. UI should remain responsive throughout',
              textProps: DCFTextProps(fontSize: 12, color: Colors.black),
            ),
            DCFText(
              content: '4. Other frameworks would freeze here!',
              textProps: DCFTextProps(
                fontSize: 12,
                fontWeight: DCFFontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Performs intentionally blocking calculation that would freeze other UIs
double performBlockingCalculation() {
  developer.log('🔥 Starting HEAVY blocking calculation...');
  double result = 0.0;

  // This is intentionally CPU-intensive and blocking
  // Increased from 5M to 20M operations
  for (int i = 0; i < 20000000; i++) {
    result += sqrt(i.toDouble()) * sin(i.toDouble()) * cos(i.toDouble());

    // Add some extra complexity
    if (i % 1000 == 0) {
      result = result / (i + 1) * pi;
    }

    // More frequent string operations
    if (i % 5000 == 0) {
      final str = 'calculation_$i';
      result += str.length;
      // Add string processing
      final reversed = str.split('').reversed.join('');
      result += reversed.length;
    }

    // Log progress every 5M operations
    if (i % 5000000 == 0 && i > 0) {
      developer.log('📊 Progress: ${(i / 20000000 * 100).toInt()}% complete');
    }
  }

  developer.log('🎯 Math operations complete, starting list processing...');

  // Additional blocking operations - increased complexity
  for (int j = 0; j < 5000; j++) {
    final list = List.generate(2000, (index) => Random().nextDouble());
    list.sort();
    result += list.first + list.last;

    // Add more list operations
    final shuffled = List<double>.from(list);
    shuffled.shuffle();
    result += shuffled.reduce((a, b) => a + b) / shuffled.length;
  }

  developer.log('✨ Blocking calculation FINISHED!');
  return result;
}
