// Pure Signals Example - ONE API for everything!

import 'package:dcflight/dcflight.dart';

class PureSignalsExample extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    // 🎯 ONE API: signal() for everything
    final count = signal(0);
    final name = signal("World");
    final showDetails = signal(false);
    
    // 🎯 Computed signals (auto-update)
    final doubled = computed(() => count() * 2);
    final greeting = computed(() => "Hello, ${name()}!");
    
    return DCFView(
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.white,
      ),
      layout: DCFLayout(
        width: '100%',
        height: '100%',
        padding: 20,
        gap: 16,
      ),
      children: [
        // ✨ Signal in PROP → Direct native update (< 1ms)
        DCFText(
          content: () => greeting(),  // Reads signal, auto-subscribes
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
        ),
        
        DCFText(
          content: () => "Count: ${count()} (doubled: ${doubled()})",
          textProps: DCFTextProps(fontSize: 18),
        ),
        
        // Button updates signal directly
        DCFTouchableOpacity(
          onPress: () => count.set(count() + 1),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.blue,
            borderRadius: 8,
          ),
          layout: DCFLayout(padding: 12),
          children: [
            DCFText(
              content: "Increment",
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
            ),
          ],
        ),
        
        // ✨ Signal in STRUCTURE → Reconciliation (~5ms)
        if (showDetails())  // Reads signal during render
          DCFView(
            styleSheet: DCFStyleSheet(
              backgroundColor: DCFColors.gray100,
              borderRadius: 8,
            ),
            layout: DCFLayout(padding: 16),
            children: [
              DCFText(
                content: "These are the details!",
                textProps: DCFTextProps(fontSize: 16),
              ),
            ],
          ),
        
        // Toggle button
        DCFTouchableOpacity(
          onPress: () => showDetails.set(!showDetails()),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.green,
            borderRadius: 8,
          ),
          layout: DCFLayout(padding: 12),
          children: [
            DCFText(
              content: () => showDetails() ? "Hide Details" : "Show Details",
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
            ),
          ],
        ),
      ],
    );
  }
}

/*
 * HOW IT WORKS:
 * 
 * 1. Signal in prop (text content):
 *    count.set(1) → updateView() directly on text node
 *    NO component re-render!
 * 
 * 2. Signal in structure (if statement):
 *    showDetails.set(true) → component.scheduleUpdate()
 *    Re-render + smart reconciliation
 * 
 * Developer writes ONE thing, engine optimizes automatically!
 * 
 * This is exactly how SolidJS/Angular work.
 */
