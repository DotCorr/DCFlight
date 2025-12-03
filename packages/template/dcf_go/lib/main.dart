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
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: Colors.white,
      ),
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
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingTop: 64,
        paddingBottom: 80,
        paddingHorizontal: 24,
        gap: 48,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.white),
      children: [
        // Left Content
        DCFView(
          layout: DCFLayout(width: '100%', gap: 32),
          children: [
            Motion(
              initial: {'opacity': 0, 'y': 20},
              animate: {'opacity': 1, 'y': 0},
              transition: Transition(duration: 800),
              layout: DCFLayout(gap: 24),
              children: [
                DCFText(
                  content: "Building\nInfrastructure\nFor The Inevitable.",
                  textProps: DCFTextProps(
                    fontSize: 48, // Closer to web h1
                    fontWeight: DCFFontWeight.medium,
                    lineHeight: 1.1, // Tighter line height like web
                    letterSpacing: -1.5,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: Colors.black),
                ),
                
                // Typewriter Effect Placeholder (simplified for now)
                DCFView(
                  layout: DCFLayout(
                    height: 60,
                    justifyContent: DCFJustifyContent.center,
                  ),
                  children: [
                TypewriterEffect(),
                  ],
                ),

                DCFView(
                  layout: DCFLayout(
                    flexDirection: DCFFlexDirection.row,
                    alignItems: DCFAlign.center,
                    marginTop: 16,
                  ),
                  children: [
                    DCFView(
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
                  children: [
                    DCFText(
                      content: "Enter The Lab",
                      textProps: DCFTextProps(
                        fontSize: 16,
                        fontWeight: DCFFontWeight.medium,
                      ),
                          styleSheet: DCFStyleSheet(primaryColor: Colors.white),
                        ),
                        // Arrow placeholder
                        DCFText(
                          content: "→",
                          textProps: DCFTextProps(fontSize: 16, fontWeight: DCFFontWeight.medium),
                          styleSheet: DCFStyleSheet(primaryColor: Colors.white),
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
          children: [
            InfrastructureVisual(),
          ],
        ),
      ],
    );
  }
}

class TypewriterEffect extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(flexDirection: DCFFlexDirection.row, alignItems: DCFAlign.center),
      children: [
        DCFText(
          content: "\$ Build for Mobile", // Static for stability first
          textProps: DCFTextProps(
            fontSize: 20,
            fontFamily: "Courier", // Monospace if available
          ),
          styleSheet: DCFStyleSheet(primaryColor: Colors.grey[600]!),
        ),
        // Cursor
        ReanimatedView(
          layout: DCFLayout(width: 10, height: 24, marginLeft: 8),
          styleSheet: DCFStyleSheet(backgroundColor: Colors.black),
          animate: {'opacity': 0},
          transition: Transition(duration: 500, repeat: true, repeatType: 'reverse'), // Blink
          children: [],
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
      initial: {'rotateX': 0, 'rotateZ': 0, 'scale': 0.8},
      animate: {'rotateX': 60, 'rotateZ': 45, 'scale': 1.0}, // Web: rotateX: 60, rotateZ: 45
      transition: Transition(duration: 2000, curve: AnimationCurve.easeOut),
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
        
        // Tower (White square rising up)
        // In standard CSS 3D, Z-index/translateZ works. Here we simulate with another view
        // offset and styled to look like a tower.
        ReanimatedView(
          layout: DCFLayout(
            width: size * 0.35,
            height: size * 0.35,
            position: DCFPositionType.absolute,
            absoluteLayout: AbsoluteLayout(
              top: size * 0.15,
              left: size * 0.15,
            ),
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Colors.white,
            shadowColor: Colors.white,
            shadowRadius: 20,
            shadowOpacity: 0.4,
          ),
          initial: {'translateY': 0}, // Simulate Z height with Y translation in this perspective? 
          // Actually, true 3D might be tricky without perspective container.
          children: [],
          // Let's keep it simple: it's a white box on a black rotated plane.
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
              layout: DCFLayout(width: '100%',height: 100),
              content: "Infrastructure for\nBuilders & Machines",
              textProps: DCFTextProps(
                fontSize: 48, // text-5xl = 48px (matches web)
                fontWeight: DCFFontWeight.medium,
                letterSpacing: -1,
                lineHeight: 1.1,
              ),
              styleSheet: DCFStyleSheet(primaryColor: Colors.black),
            ),
            DCFText(
              content: "We provide the tools to build native applications today and the cognitive architecture for the intelligent systems of tomorrow.",
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

  DCFComponentNode _buildCard(String title, String desc, Color bg, Color text, String linkText) {
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
        borderColor: bg == Colors.white ? Colors.grey[200]! : Colors.transparent,
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
              
              content: bg == Colors.white ? "📱" : "🧠",
              textProps: DCFTextProps(fontSize: 24),
              styleSheet: DCFStyleSheet(primaryColor: bg == Colors.white ? Colors.white : Colors.black),
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
                numberOfLines: 0, // Allow unlimited lines - CRITICAL for multi-line text
              ),
              styleSheet: DCFStyleSheet(
                primaryColor: text == Colors.black ? Colors.grey[500]! : Colors.grey[300]!,
              ),
              layout: DCFLayout(
                width: '100%', // Ensure text can use full width for wrapping
              ),
            ),
          ],
        ),
        // Link - inline-flex items-center gap-2
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 8, // gap-2 = 8px
          ),
          children: [
            DCFText(
              content: linkText,
              textProps: DCFTextProps(
                fontSize: 16,
                fontWeight: DCFFontWeight.medium,
                numberOfLines: 1, // Single line for link
              ),
              styleSheet: DCFStyleSheet(primaryColor: text),
              layout: DCFLayout(
                flexShrink: 0, // Text should not shrink - let it truncate if needed
              ),
            ),
            DCFText(
              content: "→",
              textProps: DCFTextProps(fontSize: 16),
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
      layout: DCFLayout(width: '100%', paddingVertical: 80, paddingHorizontal: 24),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.white),
          children: [
            DCFText(
              content: "Built for the Modern Stack",
          textProps: DCFTextProps(fontSize: 32, fontWeight: DCFFontWeight.bold, letterSpacing: -1),
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
      layout: DCFLayout(width: '100%', paddingVertical: 80, paddingHorizontal: 24),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.grey[900]!),
      children: [
            DCFText(
              content: "Designing the Cognitive Future",
          textProps: DCFTextProps(fontSize: 32, fontWeight: DCFFontWeight.bold, letterSpacing: -1),
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
