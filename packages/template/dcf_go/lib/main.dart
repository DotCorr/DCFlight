import 'dart:math' as math;

import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' show Colors;

void main() async {
  await DCFlight.go(app: DotCorrLanding());
}

/// DotCorr Landing Page - Matching Web Design
class DotCorrLanding extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: DCFLayout(
        flex: 1,
        width: '100%', // CRITICAL: Explicit width needed for Yoga to calculate child percentages
        // In Yoga's paradigm, percentage widths (like NavigationBar's width: '100%')
        // require the parent to have a DEFINED width. flex: 1 alone isn't enough
        // because Yoga needs to resolve the parent's width before calculating child percentages
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.red),
      children: [
        NavigationBar(),
        HeroSection(),
        // EcosystemSection(),
        BuildersAndMachinesSection(),
        TechnologyEcosystemSection(),
        AboutSection(),
        Footer(),
      ],
    );
  }
}

class NavigationBar extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final screenUtils = ScreenUtilities.instance;
    final safeAreaTop = screenUtils.safeAreaTop;

    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingTop: 16 + safeAreaTop,
        paddingBottom: 16,
        paddingHorizontal: 24,
        flexDirection: DCFFlexDirection.row,
        justifyContent: DCFJustifyContent.spaceBetween,
        alignItems: DCFAlign.center,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: Colors.white,
        borderBottomWidth: 1,
        borderBottomColor: Colors.grey[100]!,
      ),
      children: [
        // Logo Area - CRITICAL: Add flexShrink to prevent overflow
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 8,
            flexShrink: 1, // Allow shrinking to prevent overflow
            flexGrow: 0, // Don't grow
          ),
          children: [
            DCFView(
              layout: DCFLayout(width: 24, height: 24),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.black),
            ),
            DCFText(
              content: "DotCorr",
              textProps: DCFTextProps(
                fontSize: 18,
                fontWeight: DCFFontWeight.bold,
                letterSpacing: -0.5,
              ),
              styleSheet: DCFStyleSheet(primaryColor: Colors.black),
            ),
          ],
        ),
        // Links - CRITICAL: Add flexShrink and minWidth: 0 to prevent overflow
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 24,
            flexShrink: 1, // Allow shrinking to prevent overflow
            flexGrow: 0, // Don't grow
            minWidth: 0, // CRITICAL: Allow shrinking below content size
          ),
          children: [
            DCFText(
              content: "The Lab",
              textProps: DCFTextProps(
                fontSize: 14,
                fontWeight: DCFFontWeight.medium,
                numberOfLines: 1, // Single line with truncation
              ),
              styleSheet: DCFStyleSheet(primaryColor: Colors.grey[600]!),
              layout: DCFLayout(
                flexShrink: 1, // Allow text to shrink
                minWidth: 0, // CRITICAL: Allow shrinking below content size
              ),
            ),
            // GitHub Icon placeholder (text for now)
            DCFText(
              content: "GitHub",
              textProps: DCFTextProps(
                fontSize: 14,
                fontWeight: DCFFontWeight.medium,
                numberOfLines: 1, // Single line with truncation
              ),
              styleSheet: DCFStyleSheet(primaryColor: Colors.grey[600]!),
              layout: DCFLayout(
                flexShrink: 1, // Allow text to shrink
                minWidth: 0, // CRITICAL: Allow shrinking below content size
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HeroSection extends DCFStatefulComponent {
  
  @override
  DCFComponentNode render() {
    final showTest = useState<bool>(false);
    if (showTest.state) {
      // CRITICAL: Always return a View wrapper to maintain consistent structure
      // Returning DCFText directly breaks ScrollView's single-child constraint
      return DCFView(
        layout: DCFLayout(
          width: '100%',
          paddingTop: 128,
          paddingBottom: 80,
          paddingHorizontal: 24,
          flexDirection: DCFFlexDirection.column,
          gap: 48,
        ),
        styleSheet: DCFStyleSheet(backgroundColor: Colors.white),
        children: [
          DCFText(
            content: "Hello, World!",
            textProps: DCFTextProps(fontSize: 20),
            styleSheet: DCFStyleSheet(primaryColor: Colors.black),
          ),
        ],
      );
    }
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingTop: 128, // pt-32 = 128px (matches web)
        paddingBottom: 80, // pb-20 = 80px (matches web)
        paddingHorizontal: 24,
        flexDirection: DCFFlexDirection.column,
        gap: 48,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.white),
      children: [
        // Main content row (left text + right visual)
        DCFView(
          layout: DCFLayout(
            width: '100%',
            flexDirection: DCFFlexDirection.column,
            gap: 48,
          ),
          children: [
            // Left Content
            DCFView(
              layout: DCFLayout(width: '100%', gap: 32),
              children: [
                Motion(
                  initial: AnimationProperties(opacity: 0, y: 20),
                  animate: AnimationProperties(opacity: 1, y: 0),
                  transition: Transition(duration: 800),
                  autoStart: false,
                  layout: DCFLayout(gap: 24),
                  children: [
                    // Split text to match web styling - "For The" in gray
                    DCFView(
                      layout: DCFLayout(
                        flexDirection: DCFFlexDirection.column,
                        gap: 0,
                      ),
                      children: [
                        DCFText(
                          content: "Building",
                          textProps: DCFTextProps(
                            fontSize: 48,
                            fontWeight: DCFFontWeight.medium,
                            lineHeight: 1.1,
                            letterSpacing: -1.5,
                          ),
                          styleSheet: DCFStyleSheet(primaryColor: Colors.black),
                        ),
                        DCFText(
                          content: "Infrastructure",
                          textProps: DCFTextProps(
                            fontSize: 48,
                            fontWeight: DCFFontWeight.medium,
                            lineHeight: 1.1,
                            letterSpacing: -1.5,
                          ),
                          styleSheet: DCFStyleSheet(primaryColor: Colors.black),
                        ),
                        DCFView(
                          layout: DCFLayout(
                            flexDirection: DCFFlexDirection.row,
                            gap: 0,
                          ),
                          children: [
                            DCFText(
                              content: "For The ",
                              textProps: DCFTextProps(
                                fontSize: 48,
                                fontWeight: DCFFontWeight.medium,
                                lineHeight: 1.1,
                                letterSpacing: -1.5,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: Colors.grey[300]!,
                              ),
                            ),
                            DCFText(
                              content: "Inevitable.",
                              textProps: DCFTextProps(
                                fontSize: 48,
                                fontWeight: DCFFontWeight.medium,
                                lineHeight: 1.1,
                                letterSpacing: -1.5,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Typewriter Effect (Worklet-based - runs on UI thread)
                    DCFView(
                      layout: DCFLayout(
                        height: 80, // h-20 = 80px (matches web)
                        justifyContent: DCFJustifyContent.center,
                        marginBottom: 40, // mb-10 = 40px (matches web)
                      ),
                      children: [TypewriterEffectWorklet()],
                    ),

                    // Button
                    DCFView(
                      layout: DCFLayout(
                        flexDirection: DCFFlexDirection.row,
                        alignItems: DCFAlign.center,
                      ),
                      children: [
                        DCFButton(
                          layout: DCFLayout(
                            paddingHorizontal: 32,
                            paddingVertical: 16,
                            flexDirection: DCFFlexDirection.row,
                            alignItems: DCFAlign.center,
                            gap: 12,
                          ),
                          styleSheet: DCFStyleSheet(
                            backgroundColor: Colors.black,
                            borderRadius: 2, // Small radius like web
                          ),
                          onPress: (data) {
                            print('🔍🔍🔍 Button pressed');
                            showTest.setState(!showTest.state);
                          },
                          children: [
                            DCFText(
                              content: "Enter The Lab",
                              textProps: DCFTextProps(
                                fontSize: 16,
                                fontWeight: DCFFontWeight.medium,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: Colors.white,
                              ),
                            ),
                            DCFText(
                              content: "→",
                              textProps: DCFTextProps(
                                fontSize: 16,
                                fontWeight: DCFFontWeight.medium,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Right Visual (3D Box effect using Reanimated)
            DCFView(
              layout: DCFLayout(
                width: '100%',
                height: 400, // Fixed height container for the visual
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
              ),
              children: [InfrastructureVisual()],
            ),
          ],
        ),
      ],
    );
  }
}

/// Typewriter Effect Component
///
/// CURRENT IMPLEMENTATION: Uses Dart timers and state (runs on Dart thread)
/// - 2-12% CPU usage
/// - Bridge calls for every character update
/// - Can be blocked by Dart thread operations
///
/// FUTURE: Will migrate to worklet-based implementation (runs on UI thread)
/// - <1% CPU usage expected
/// - Zero bridge calls during animation
/// - 60fps guaranteed, cannot be blocked
class TypewriterEffect extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final words = [
      "Build for Mobile.",
      "Build for Web.",
      "Build for AI.",
      "Build for AGI.",
      "Build for The Future.",
    ];

    final index = useState<int>(0);
    final subIndex = useState<int>(0);
    final reverse = useState<bool>(false);
    final blink = useState<bool>(true);

    // Cursor blinking effect - runs independently
    useEffect(() {
      final timer = Timer.periodic(Duration(milliseconds: 500), (_) {
        blink.setState(!blink.state);
      });
      return () => timer.cancel();
    }, dependencies: []);

    // Typewriter logic - matches web version behavior
    // The framework ensures this effect runs reliably on mount and only re-runs when dependencies change
    // This prevents unnecessary cleanup during reconciliation loops
    useEffect(() {
      Timer? timer;
      final currentWord = words[index.state];
      final wordLength = currentWord.length;
      final currentSubIndex = subIndex.state;
      final isReversing = reverse.state;

      // If we've typed past the end, wait then start deleting
      if (currentSubIndex == wordLength && !isReversing) {
        timer = Timer(Duration(milliseconds: 2000), () {
          if (subIndex.state == wordLength && !reverse.state) {
            reverse.setState(true);
          }
        });
        return () => timer?.cancel();
      }

      // If we've deleted everything and reversing, move to next word
      if (currentSubIndex == 0 && isReversing) {
        reverse.setState(false);
        index.setState((index.state + 1) % words.length);
        // Don't set timer here - let the effect re-run with new state
        return () {};
      }

      // Default: continue typing or deleting
      // This handles initial state (0, false) and all in-progress states
      final speed = isReversing ? 50 : 100;
      timer = Timer(Duration(milliseconds: speed), () {
        // Get fresh state values to avoid stale closures
        final currentReverse = reverse.state;
        final currentSub = subIndex.state;
        final currentWordLen = words[index.state].length;

        if (currentReverse) {
          // Deleting - move backwards
          if (currentSub > 0) {
            subIndex.setState(currentSub - 1);
          }
        } else {
          // Typing - move forwards (including initial state 0 -> 1)
          if (currentSub < currentWordLen) {
            subIndex.setState(currentSub + 1);
          }
        }
      });
      return () => timer?.cancel();
    }, dependencies: [subIndex.state, index.state, reverse.state]);

    final currentText = words[index.state].substring(0, subIndex.state);
    final cursorChar =
        blink.state ? '▊' : ' '; // Use block character for cursor

    // Combine text and cursor in a single text component for proper positioning
    // Use a fixed-width container to prevent layout jumps when switching words
    final longestWord = words.reduce((a, b) => a.length > b.length ? a : b);
    final estimatedWidth =
        longestWord.length * 12.0; // Approximate width per character

    return DCFView(
      layout: DCFLayout(
        flexDirection: DCFFlexDirection.row,
        alignItems: DCFAlign.center,
        minWidth: estimatedWidth, // Prevent layout shifts
      ),
      children: [
        DCFText(
          content: "\$ ",
          textProps: DCFTextProps(fontSize: 20, fontFamily: "Courier"),
          styleSheet: DCFStyleSheet(primaryColor: Colors.grey[400]!),
        ),
        DCFText(
          content: "$currentText$cursorChar",
          textProps: DCFTextProps(fontSize: 20, fontFamily: "Courier"),
          styleSheet: DCFStyleSheet(primaryColor: Colors.grey[600]!),
        ),
      ],
    );
  }
}

/// Worklet-based Typewriter Effect (runs on UI thread)
///
/// This is the optimized version that runs entirely on the UI thread with zero bridge calls.
/// It uses AnimatedText component with a worklet function.
@Worklet()
String typewriterWorklet(
  double elapsed,
  List<String> words,
  double typeSpeed,
  double deleteSpeed,
  double pauseDuration,
) {
  // Calculate total time per word cycle
  double totalTimePerCycle = 0;
  for (String word in words) {
    totalTimePerCycle +=
        (word.length * typeSpeed / 1000.0) +
        pauseDuration / 1000.0 +
        (word.length * deleteSpeed / 1000.0);
  }

  // Find current word and position based on elapsed time
  double cycleTime = elapsed % totalTimePerCycle;
  int wordIndex = 0;
  double accumulatedTime = 0;

  for (int i = 0; i < words.length; i++) {
    String word = words[i];
    double wordTypeTime = word.length * typeSpeed / 1000.0;
    double wordPauseTime = pauseDuration / 1000.0;
    double wordDeleteTime = word.length * deleteSpeed / 1000.0;
    double wordTotalTime = wordTypeTime + wordPauseTime + wordDeleteTime;

    if (cycleTime <= accumulatedTime + wordTotalTime) {
      wordIndex = i;
      break;
    }
    accumulatedTime += wordTotalTime;
  }

  String currentWord = words[wordIndex];
  double wordStartTime = accumulatedTime;
  double wordTypeTime = currentWord.length * typeSpeed / 1000.0;
  double wordPauseTime = pauseDuration / 1000.0;

  double relativeTime = cycleTime - wordStartTime;

  if (relativeTime < wordTypeTime) {
    // Typing phase
    int charIndex = (relativeTime / (typeSpeed / 1000.0)).floor();
    return currentWord.substring(0, math.min(charIndex, currentWord.length));
  } else if (relativeTime < wordTypeTime + wordPauseTime) {
    // Pause phase - show full word
    return currentWord;
  } else {
    // Deleting phase
    double deleteStartTime = wordTypeTime + wordPauseTime;
    double deleteElapsed = relativeTime - deleteStartTime;
    int charsToDelete = (deleteElapsed / (deleteSpeed / 1000.0)).floor();
    int remainingChars = math.max(0, currentWord.length - charsToDelete);
    return currentWord.substring(
      0,
      math.min(remainingChars, currentWord.length),
    );
  }
}

/// Worklet-based typewriter effect using AnimatedText
class TypewriterEffectWorklet extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final words = [
      "Build for Mobile.",
      "Build for Web.",
      "Build for AI.",
      "Build for AGI.",
      "Build for The Future.",
    ];

    return DCFView(
      layout: DCFLayout(
        flexDirection: DCFFlexDirection.row,
        alignItems: DCFAlign.center,
      ),
      children: [
        DCFText(
          content: "\$ ",
          textProps: DCFTextProps(fontSize: 20, fontFamily: "Courier"),
          styleSheet: DCFStyleSheet(primaryColor: Colors.grey[400]!),
        ),
        AnimatedText(
          worklet: typewriterWorklet,
          workletConfig: {
            'words': words,
            'typeSpeed': 100.0,
            'deleteSpeed': 50.0,
            'pauseDuration': 2000.0,
          },
          textProps: DCFTextProps(fontSize: 20, fontFamily: "Courier"),
          styleSheet: DCFStyleSheet(primaryColor: Colors.grey[600]!),
        ),
      ],
    );
  }
}

class InfrastructureVisual extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final size = 200.0;

    // Mimicking the 3D structure from web using Reanimated transforms
    return ReanimatedView(
      layout: DCFLayout(
        width: size,
        height: size,
        alignItems: DCFAlign.center,
        justifyContent: DCFJustifyContent.center,
      ),
      initial: AnimationProperties(rotateX: 0, rotateZ: 0, scale: 0.8),
      animate: AnimationProperties(rotateX: 60, rotateZ: 45, scale: 1.0),
      transition: Transition(
        duration: 2500, // Match web duration
        cubicBezier: [0.16, 1, 0.3, 1], // Smooth ease-out like web
      ),
      autoStart: false,
      children: [
        // Base (Black background)
        DCFView(
          layout: DCFLayout(
            width: size,
            height: size,
            position: DCFPositionType.absolute,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Colors.black,
            borderWidth: 1,
            borderColor: Colors.grey[900]!,
          ),
        ),

        // Tower (White square rising up with 3D translateZ)
        ReanimatedView(
          layout: DCFLayout(
            width: size * 0.35,
            height: size * 0.35,
            position: DCFPositionType.absolute,
            absoluteLayout: AbsoluteLayout(top: size * 0.15, left: size * 0.15),
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Colors.white,
            shadowColor: Colors.white,
            shadowRadius: 20,
            shadowOpacity: 0.4,
          ),
          initial: AnimationProperties(translateZ: 0),
          animate: AnimationProperties(
            translateZ: 80,
          ), // Tower height in 3D space
          transition: Transition(
            duration: 2000,
            delay: 800,
            curve: AnimationCurve.easeOut,
          ),
          autoStart: false,
          children: [],
        ),
      ],
    );
  }
}

class BuildersAndMachinesSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingVertical: 128, // py-32 = 128px (matches web)
        paddingHorizontal: 24,
        flexDirection: DCFFlexDirection.column,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.grey[50]!),
      children: [
        // Header section - mb-20 = 80px
        DCFView(
          layout: DCFLayout(
            width: '100%',
            marginBottom: 80,
            flexDirection: DCFFlexDirection.column,
            gap: 32,
          ),
          children: [
            DCFText(
              layout: DCFLayout(width: '100%'),
              content: "Infrastructure for\nBuilders & Machines",
              textProps: DCFTextProps(
                fontSize: 48, // text-5xl = 48px (matches web)
                fontWeight: DCFFontWeight.medium,
                letterSpacing: -1,
                lineHeight: 1.1,
                numberOfLines: 0, // Allow unlimited lines - CRITICAL for multi-line text
              ),
              styleSheet: DCFStyleSheet(primaryColor: Colors.black),
            ),
            DCFText(
              content:
                  "We provide the tools to build native applications today and the cognitive architecture for the intelligent systems of tomorrow.",
              textProps: DCFTextProps(
                fontSize: 20, // text-xl = 20px (matches web)
                lineHeight: 1.6,
              ),
              styleSheet: DCFStyleSheet(primaryColor: Colors.grey[500]!),
            ),
          ],
        ),
        // Cards - gap-8 = 32px
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.column,
            gap: 32, // gap-8 = 32px (matches web)
          ),
          children: [
            _buildCard(
              "For Builders",
              "Direct access to native platform capabilities. Write Dart once, render true native UI components. No abstractions, no compromises.",
              Colors.white,
              Colors.black,
              "Explore DCFlight",
            ),
            _buildCard(
              "For Machines",
              "The cognitive layer for artificial intelligence. We build the foundational systems required to support autonomous agents and AGI.",
              Colors.black,
              Colors.white,
              "Explore DCCortex",
            ),
          ],
        ),
      ],
    );
  }

  DCFComponentNode _buildCard(
    String title,
    String desc,
    Color bg,
    Color text,
    String linkText,
  ) {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        padding: 40, // p-10 = 40px (matches web)
        flexDirection: DCFFlexDirection.column,
        alignItems: DCFAlign.flexStart, // Align items to start
        flexShrink: 0, // Don't shrink - let content define height
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: bg,
        borderWidth: bg == Colors.white ? 1 : 0,
        borderColor:
            bg == Colors.white ? Colors.grey[200]! : Colors.transparent,
        borderRadius: 8,
        shadowColor: Colors.black,
        shadowOpacity: bg == Colors.white ? 0.05 : 0.3,
        shadowRadius: bg == Colors.white ? 4 : 12,
        shadowOffsetX: 0,
        shadowOffsetY: bg == Colors.white ? 1 : 4,
      ),
      children: [
        // Icon - matches web w-12 h-12 = 48px
        DCFView(
          layout: DCFLayout(
            width: 48,
            height: 48,
            alignItems: DCFAlign.center,
            justifyContent: DCFJustifyContent.center,
            marginBottom: 24, // mb-6 = 24px
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: bg == Colors.white ? Colors.black : Colors.white,
            borderRadius: 4,
          ),
          children: [
            DCFText(
              layout: DCFLayout(
                width: 48,
                height: 48,
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
              ),
              content: bg == Colors.white ? "📱" : "🧠",
              textProps: DCFTextProps(
                fontSize: 24,
                textAlign: DCFTextAlign.center,
              ),
              styleSheet: DCFStyleSheet(
                primaryColor: bg == Colors.white ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        // Title - text-2xl font-bold mb-3
        DCFView(
          layout: DCFLayout(
            width: '100%',
            marginBottom: 12, // mb-3 = 12px
          ),
          children: [
            DCFText(
              content: title,
              textProps: DCFTextProps(
                fontSize: 24, // text-2xl = 24px
                fontWeight: DCFFontWeight.bold,
                textAlign: DCFTextAlign.left, // Left align text
              ),
              styleSheet: DCFStyleSheet(primaryColor: text),
            ),
          ],
        ),
        // Description - mb-8 - CRITICAL: Must have width: 100% to wrap properly
        DCFView(
          layout: DCFLayout(
            width: '100%',
            marginBottom: 32, // mb-8 = 32px
            flexShrink: 0, // Don't shrink
          ),
          children: [
            DCFText(
              content: desc,
              textProps: DCFTextProps(
                fontSize: 16,
                lineHeight: 1.5,
                numberOfLines:
                    0, // Allow unlimited lines - CRITICAL for multi-line text
                textAlign: DCFTextAlign.left, // Left align text
              ),
              styleSheet: DCFStyleSheet(
                primaryColor:
                    text == Colors.black
                        ? Colors.grey[500]!
                        : Colors.grey[300]!,
              ),
              // Remove explicit width - let text size naturally based on parent constraints
              // Yoga will automatically constrain it to parent's available width (after padding)
            ),
          ],
        ),
        // Link - inline-flex items-center gap-2
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 8, // gap-2 = 8px
            justifyContent: DCFJustifyContent.flexStart, // Align to start (left)
          ),
          children: [
            DCFText(
              content: linkText,
              textProps: DCFTextProps(
                fontSize: 16,
                fontWeight: DCFFontWeight.medium,
                numberOfLines: 1, // Single line for link
                textAlign: DCFTextAlign.left, // Left align text
              ),
              styleSheet: DCFStyleSheet(primaryColor: text),
              layout: DCFLayout(
                flexShrink:
                    0, // Text should not shrink - let it truncate if needed
              ),
            ),
            DCFText(
              content: "→",
              textProps: DCFTextProps(
                fontSize: 16,
                textAlign: DCFTextAlign.left, // Left align arrow
              ),
              styleSheet: DCFStyleSheet(primaryColor: text),
              layout: DCFLayout(
                flexShrink: 0, // Arrow should not shrink
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TechnologyEcosystemSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingVertical: 80,
        paddingHorizontal: 24,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.white),
      children: [
        DCFText(
          content: "Built for the Modern Stack",
          textProps: DCFTextProps(
            fontSize: 32,
            fontWeight: DCFFontWeight.bold,
            letterSpacing: -1,
          ),
          styleSheet: DCFStyleSheet(primaryColor: Colors.black),
        ),
        // Grid items... (Simplified)
      ],
    );
  }
}

class AboutSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingVertical: 80,
        paddingHorizontal: 24,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.grey[900]!),
      children: [
        DCFText(
          content: "Designing the Cognitive Future",
          textProps: DCFTextProps(
            fontSize: 32,
            fontWeight: DCFFontWeight.bold,
            letterSpacing: -1,
          ),
          styleSheet: DCFStyleSheet(primaryColor: Colors.white),
        ),
      ],
    );
  }
}

class Footer extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final screenUtils = ScreenUtilities.instance;
    final safeAreaBottom = screenUtils.safeAreaBottom;

    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingTop: 48,
        paddingBottom: 32 + safeAreaBottom,
        paddingHorizontal: 24,
        gap: 40,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.white),
      children: [
        DCFText(
          content: "© 2025 DotCorr. All rights reserved.",
          textProps: DCFTextProps(fontSize: 14),
          styleSheet: DCFStyleSheet(primaryColor: Colors.grey[500]!),
        ),
      ],
    );
  }
}
