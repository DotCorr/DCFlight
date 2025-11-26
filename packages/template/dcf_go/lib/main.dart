import 'package:dcf_go/style.dart';
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/dcflight.dart';
import 'dart:math' as math;

void main() async {
  await DCFlight.go(app: DotCorrLanding());
}

/// DotCorr Landing Page - Recreated from React/Framer Motion
class DotCorrLanding extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: layouts['root'],
      styleSheet: styles['root'],
      children: [
        // Navigation
        NavigationBar(),
        
        // Hero Section
        HeroSection(),
        
        // Infrastructure for Builders & Machines
        BuildersAndMachinesSection(),
        
        // Technology Ecosystem
        TechnologyEcosystemSection(),
        
        // About Section
        AboutSection(),
        
        // Footer
        Footer(),
      ],
    );
  }
}

/// Navigation Bar Component
class NavigationBar extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return Motion(
      initial: { 'opacity': 0, 'y': -20 },
      animate: { 'opacity': 1, 'y': 0 },
      transition: Transition(duration: 600),
      layout: layouts['nav'],
      styleSheet: styles['nav'],
      children: [
        DCFView(
          layout: layouts['navContainer'],
          children: [
            DCFView(
              layout: layouts['navLogo'],
              children: [
                DCFText(
                  content: "DotCorr",
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['navLogoText'],
                ),
              ],
            ),
            DCFView(
              layout: layouts['navLinks'],
              children: [
                DCFText(
                  content: "The Lab",
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: styles['navLink'],
                ),
                DCFText(
                  content: "GitHub",
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: styles['navLink'],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Hero Section Component
class HeroSection extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: layouts['hero'],
      styleSheet: styles['hero'],
      children: [
        DCFView(
          layout: layouts['heroContainer'],
          children: [
            // Left: Typography & Message
            Motion(
              initial: { 'opacity': 0, 'y': 20 },
              animate: { 'opacity': 1, 'y': 0 },
              transition: Transition(duration: 800),
              layout: layouts['heroLeft'],
              children: [
                DCFText(
                  content: "Building\nInfrastructure\nFor The Inevitable.",
                  textProps: DCFTextProps(
                    fontSize: 64,
                    fontWeight: DCFFontWeight.medium,
                  ),
                  styleSheet: styles['heroTitle'],
                ),
                TypewriterEffect(),
                DCFButton(
                  onPress: (data) {},
                  styleSheet: styles['heroButton'],
                  layout: layouts['heroButton'],
                  children: [
                    DCFText(
                      content: "Enter The Lab",
                      textProps: DCFTextProps(
                        fontSize: 16,
                        fontWeight: DCFFontWeight.medium,
                      ),
                      styleSheet: styles['heroButtonText'],
                    ),
                  ],
                ),
              ],
            ),
            
            // Right: Infrastructure Visualization
            DCFView(
              layout: layouts['heroRight'],
              children: [
                InfrastructureVisual(),
              ],
            ),
          ],
        ),
        
        // Ecosystem/Model Compatibility
        Motion(
          initial: { 'opacity': 0, 'y': 20 },
          animate: { 'opacity': 1, 'y': 0 },
          transition: Transition(delay: 500, duration: 800),
          layout: layouts['ecosystem'],
          children: [
            DCFText(
              content: "Interoperable with leading foundation models",
              textProps: DCFTextProps(fontSize: 12),
              styleSheet: styles['ecosystemLabel'],
            ),
            DCFView(
              layout: layouts['ecosystemLogos'],
              children: [
                DCFText(content: "OpenAI", styleSheet: styles['ecosystemLogo']),
                DCFText(content: "Gemini", styleSheet: styles['ecosystemLogo']),
                DCFText(content: "Anthropic", styleSheet: styles['ecosystemLogo']),
                DCFText(content: "Meta", styleSheet: styles['ecosystemLogo']),
                DCFText(content: "Mistral", styleSheet: styles['ecosystemLogo']),
                DCFText(content: "Cohere", styleSheet: styles['ecosystemLogo']),
                DCFText(content: "+ Any LLM", styleSheet: styles['ecosystemLogo']),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Typewriter Effect Component
class TypewriterEffect extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final words = [
      "Build for Mobile.",
      "Build for Web.",
      "Build for AI.",
      "Build for AGI.",
      "Build for The Future."
    ];
    final index = useState<int>(0);
    final subIndex = useState<int>(0);
    final blink = useState<bool>(true);
    
    // Typewriter logic would go here with useEffect hooks
    // For now, showing current word
    final currentWord = words[index.state];
    final displayText = currentWord.substring(0, math.min(subIndex.state, currentWord.length));
    
    return DCFView(
      layout: layouts['typewriter'],
      children: [
        DCFText(
          content: "\$ $displayText${blink.state ? '|' : ' '}",
          textProps: DCFTextProps(
            fontSize: 20,
            fontFamily: 'monospace',
          ),
          styleSheet: styles['typewriterText'],
        ),
      ],
    );
  }
}

/// Infrastructure Visualization Component (3D)
class InfrastructureVisual extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final size = 240.0;
    final towerSize = size * 0.35;
    final towerOffset = size * 0.15;
    final towerHeight = 160.0;
    
    return DCFView(
      layout: layouts['infraContainer'],
      children: [
        // Main 3D Container
        Motion(
          initial: { 
            'opacity': 0, 
            'rotateX': 60 * (math.pi / 180), 
            'rotateZ': 45 * (math.pi / 180), 
            'scale': 0.8 
          },
          animate: { 
            'opacity': 1, 
            'rotateX': 60 * (math.pi / 180), 
            'rotateZ': 45 * (math.pi / 180), 
            'scale': 1 
          },
          transition: Transition(
            duration: 1200,
            curve: AnimationCurve.easeOut,
          ),
          layout: DCFLayout(
            width: size,
            height: size,
            position: DCFPositionType.absolute,
          ),
          children: [
            // Base (Black Platform)
            Base3D(),
            
            // Tower (White Extruded)
            Motion(
              initial: { 'z': 0 },
              animate: { 'z': towerHeight },
              transition: Transition(
                duration: 1500,
                delay: 500,
                type: 'spring',
                damping: 20,
              ),
              layout: DCFLayout(
                width: towerSize,
                height: towerSize,
                position: DCFPositionType.absolute,
                absoluteLayout: AbsoluteLayout(
                  left: towerOffset,
                  top: towerOffset,
                ),
              ),
              children: [
                Tower3D(towerHeight: towerHeight),
              ],
            ),
            
            // Orbiting Drones
            ...List.generate(3, (i) => DroneOrbit(
              index: i,
              size: size,
              delay: i * -3,
              duration: 10 + (i * 2),
            )),
            
            // Data Streams (SVG lines would go here)
            DataStreams(size: size),
            
            // Energy Particles
            ...List.generate(2, (i) => EnergyParticle(
              index: i,
              towerOffset: towerOffset,
              towerSize: towerSize,
              towerHeight: towerHeight,
              delay: i * 1.25,
            )),
          ],
        ),
      ],
    );
  }
}

/// 3D Base Component
class Base3D extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        height: '100%',
        position: DCFPositionType.absolute,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: const Color(0xFF000000),
      ),
      children: [
        // Grid pattern overlay would go here
        DCFView(
          layout: DCFLayout(
            width: '100%',
            height: '100%',
            position: DCFPositionType.absolute,
          ),
          styleSheet: DCFStyleSheet(
            opacity: 0.3,
            // Grid background would be set via native
          ),
        ),
      ],
    );
  }
}

/// 3D Tower Component
class Tower3D extends DCFStatelessComponent {
  final double towerHeight;
  
  Tower3D({required this.towerHeight});
  
  @override
  DCFComponentNode render() {
    return Motion(
      animate: {
        'opacity': [0.1, 0.5, 0.1],
        'scale': [1, 1.1, 1],
      },
      transition: Transition(
        duration: 2000,
        repeat: true,
        curve: AnimationCurve.easeInOut,
      ),
      layout: DCFLayout(
        width: '100%',
        height: '100%',
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: const Color(0xFFFFFFFF),
      ),
      children: [
        // Tower faces would be rendered via 3D transforms
      ],
    );
  }
}

/// Orbiting Drone Component
class DroneOrbit extends DCFStatelessComponent {
  final int index;
  final double size;
  final int delay;
  final int duration;
  
  DroneOrbit({
    required this.index,
    required this.size,
    required this.delay,
    required this.duration,
  });
  
  @override
  DCFComponentNode render() {
    final orbitRadius = size * 0.6;
    return Motion(
      animate: { 'rotateZ': 360 * (math.pi / 180) },
      transition: Transition(
        duration: duration * 1000,
        repeat: true,
        curve: AnimationCurve.linear,
        delay: delay * 1000,
      ),
      layout: DCFLayout(
        position: DCFPositionType.absolute,
        absoluteLayout: AbsoluteLayout.centered(),
        width: 8,
        height: 8,
      ),
      children: [
        DCFView(
          layout: DCFLayout(
            width: 8,
            height: 8,
            position: DCFPositionType.absolute,
            absoluteLayout: AbsoluteLayout(left: orbitRadius),
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: const Color(0xFFFFFFFF),
            borderRadius: 2,
          ),
          children: [
            // Scan beam would go here
            Motion(
              animate: { 'opacity': [0.2, 0.6, 0.2] },
              transition: Transition(
                duration: 2000,
                repeat: true,
              ),
              layout: DCFLayout(
                width: 80,
                height: 80,
                position: DCFPositionType.absolute,
                absoluteLayout: AbsoluteLayout.centered(),
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: const Color(0xFF06B6D4),
                opacity: 0.2,
                borderRadius: 40,
              ),
              children: [],
            ),
          ],
        ),
      ],
    );
  }
}

/// Data Streams Component
class DataStreams extends DCFStatelessComponent {
  final double size;
  
  DataStreams({required this.size});
  
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        height: '100%',
        position: DCFPositionType.absolute,
      ),
      children: [
        // Horizontal lines
        ...List.generate(4, (i) => Motion(
          initial: { 'scaleY': 0, 'opacity': 0 },
          animate: { 
            'scaleY': 1, 
            'opacity': [0.3, 0.8, 0.3] 
          },
          transition: Transition(
            duration: 800,
            delay: (1000 + (i * 100)).round(),
            repeat: true,
            repeatCount: null,
          ),
          layout: DCFLayout(
            width: 2,
            height: size * 0.5,
            position: DCFPositionType.absolute,
            absoluteLayout: AbsoluteLayout(
              left: size - (i * 35),
              top: size * 0.25,
            ),
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: const Color(0xFF06B6D4),
            opacity: 0.8,
          ),
          children: [],
        )),
        // Vertical lines
        ...List.generate(4, (i) => Motion(
          initial: { 'scaleX': 0, 'opacity': 0 },
          animate: { 
            'scaleX': 1, 
            'opacity': [0.3, 0.8, 0.3] 
          },
          transition: Transition(
            duration: 800,
            delay: (1200 + (i * 100)).round(),
            repeat: true,
            repeatCount: null,
          ),
          layout: DCFLayout(
            width: size * 0.5,
            height: 2,
            position: DCFPositionType.absolute,
            absoluteLayout: AbsoluteLayout(
              left: size * 0.25,
              top: size - (i * 35),
            ),
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: const Color(0xFF06B6D4),
            opacity: 0.8,
          ),
          children: [],
        )),
      ],
    );
  }
}

/// Energy Particle Component
class EnergyParticle extends DCFStatelessComponent {
  final int index;
  final double towerOffset;
  final double towerSize;
  final double towerHeight;
  final double delay;
  
  EnergyParticle({
    required this.index,
    required this.towerOffset,
    required this.towerSize,
    required this.towerHeight,
    required this.delay,
  });
  
  @override
  DCFComponentNode render() {
    return Motion(
      animate: {
        'z': [0, towerHeight + 10, 0],
        'opacity': [0, 1, 0],
        'scale': [1, 1.5, 1],
      },
      transition: Transition(
        duration: 2500,
        repeat: true,
        delay: (delay * 1000).round(),
        curve: AnimationCurve.easeInOut,
      ),
      layout: DCFLayout(
        width: 4,
        height: 4,
        position: DCFPositionType.absolute,
        absoluteLayout: AbsoluteLayout(
          left: towerOffset + towerSize / 2,
          top: towerOffset + towerSize / 2,
        ),
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: const Color(0xFF06B6D4),
        borderRadius: 2,
      ),
      children: [],
    );
  }
}

/// Builders & Machines Section
class BuildersAndMachinesSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: layouts['section'],
      styleSheet: styles['sectionGray'],
      children: [
        Motion(
          initial: { 'opacity': 0, 'y': 20 },
          whileInView: { 'opacity': 1, 'y': 0 },
          viewport: ViewportConfig(once: true),
          transition: Transition(duration: 600),
          layout: layouts['sectionHeader'],
          children: [
            DCFText(
              content: "Infrastructure for\nBuilders & Machines",
              textProps: DCFTextProps(
                fontSize: 48,
                fontWeight: DCFFontWeight.medium,
              ),
              styleSheet: styles['sectionTitle'],
            ),
            DCFText(
              content: "We provide the tools to build native applications today and the cognitive architecture for the intelligent systems of tomorrow.",
              textProps: DCFTextProps(fontSize: 20),
              styleSheet: styles['sectionDescription'],
            ),
          ],
        ),
        DCFView(
          layout: layouts['cardsGrid'],
          children: [
            // Builders Card
            Motion(
              initial: { 'opacity': 0, 'y': 20 },
              whileInView: { 'opacity': 1, 'y': 0 },
              whileHover: { 'y': -5 },
              viewport: ViewportConfig(once: true),
              transition: Transition(duration: 600, delay: 200),
              layout: layouts['card'],
              styleSheet: styles['cardWhite'],
              children: [
                DCFText(
                  content: "For Builders",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['cardTitle'],
                ),
                DCFText(
                  content: "Direct access to native platform capabilities. Write Dart once, render true native UI components. No abstractions, no compromises.",
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: styles['cardDescription'],
                ),
              ],
            ),
            // Machines Card
            Motion(
              initial: { 'opacity': 0, 'y': 20 },
              whileInView: { 'opacity': 1, 'y': 0 },
              whileHover: { 'y': -5 },
              viewport: ViewportConfig(once: true),
              transition: Transition(duration: 600, delay: 400),
              layout: layouts['card'],
              styleSheet: styles['cardBlack'],
              children: [
                DCFText(
                  content: "For Machines",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['cardTitleWhite'],
                ),
                DCFText(
                  content: "The cognitive layer for artificial intelligence. We build the foundational systems required to support autonomous agents and AGI.",
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: styles['cardDescriptionWhite'],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Technology Ecosystem Section
class TechnologyEcosystemSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final features = [
      {'title': 'High Performance', 'desc': 'Rust-powered core architecture ensuring maximum efficiency and memory safety at scale.'},
      {'title': 'Cross Platform', 'desc': 'Deploy native applications to iOS, Android, and Web from a single unified codebase.'},
      {'title': 'LLM Agnostic', 'desc': 'Plug-and-play compatibility with foundation models from OpenAI, Anthropic, and Llama.'},
      {'title': 'Vector Native', 'desc': 'Built-in high-performance vector search and graph capabilities for AI memory systems.'},
    ];
    
    return DCFView(
      layout: layouts['section'],
      styleSheet: styles['section'],
      children: [
        Motion(
          initial: { 'opacity': 0, 'y': 20 },
          whileInView: { 'opacity': 1, 'y': 0 },
          viewport: ViewportConfig(once: true),
          layout: layouts['sectionHeader'],
          children: [
            DCFText(
              content: "Built for the Modern Stack",
              textProps: DCFTextProps(
                fontSize: 40,
                fontWeight: DCFFontWeight.bold,
              ),
              styleSheet: styles['sectionTitle'],
            ),
            DCFText(
              content: "Our infrastructure is designed to integrate seamlessly with the technologies that power the world's most ambitious software.",
              textProps: DCFTextProps(fontSize: 20),
              styleSheet: styles['sectionDescription'],
            ),
          ],
        ),
        DCFView(
          layout: layouts['featuresGrid'],
          children: features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            return Motion(
              initial: { 'opacity': 0 },
              whileInView: { 'opacity': 1 },
              viewport: ViewportConfig(once: true),
              transition: Transition(delay: index * 100),
              layout: layouts['featureCard'],
              styleSheet: styles['featureCard'],
              children: [
                DCFText(
                  content: feature['title']!,
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['featureTitle'],
                ),
                DCFText(
                  content: feature['desc']!,
                  textProps: DCFTextProps(fontSize: 12),
                  styleSheet: styles['featureDescription'],
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// About Section
class AboutSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: layouts['section'],
      styleSheet: styles['sectionDark'],
      children: [
        Motion(
          initial: { 'opacity': 0, 'y': 20 },
          whileInView: { 'opacity': 1, 'y': 0 },
          viewport: ViewportConfig(once: true),
          transition: Transition(duration: 600),
          layout: layouts['aboutContainer'],
          children: [
            DCFText(
              content: "About DotCorr",
              textProps: DCFTextProps(
                fontSize: 14,
                fontWeight: DCFFontWeight.medium,
              ),
              styleSheet: styles['aboutLabel'],
            ),
            DCFText(
              content: "Designing the Cognitive Future",
              textProps: DCFTextProps(
                fontSize: 32,
                fontWeight: DCFFontWeight.bold,
              ),
              styleSheet: styles['aboutTitle'],
            ),
            DCFText(
              content: "DotCorr is a software design and production company specializing in next-generation infrastructure. Based in the Netherlands, we bridge the gap between today's applications and tomorrow's autonomous systems.",
              textProps: DCFTextProps(fontSize: 18),
              styleSheet: styles['aboutDescription'],
            ),
            DCFView(
              layout: layouts['aboutInfo'],
              children: [
                DCFText(content: "Location: Netherlands", styleSheet: styles['aboutInfoText']),
                DCFText(content: "Focus: AI Infrastructure & Mobile", styleSheet: styles['aboutInfoText']),
                DCFText(content: "Status: Research & Development", styleSheet: styles['aboutInfoText']),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Footer Component
class Footer extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: layouts['footer'],
      styleSheet: styles['footer'],
      children: [
        DCFView(
          layout: layouts['footerContainer'],
          children: [
            DCFView(
              layout: layouts['footerBrand'],
              children: [
                DCFText(
                  content: "DotCorr",
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['footerBrandText'],
                ),
                DCFText(
                  content: "Building the cognitive infrastructure for artificial general intelligence and high-performance mobile applications.",
                  textProps: DCFTextProps(fontSize: 12),
                  styleSheet: styles['footerDescription'],
                ),
              ],
            ),
            DCFView(
              layout: layouts['footerLinks'],
              children: [
                DCFText(content: "DCFlight", styleSheet: styles['footerLink']),
                DCFText(content: "DCCortex", styleSheet: styles['footerLink']),
                DCFText(content: "Documentation", styleSheet: styles['footerLink']),
                DCFText(content: "GitHub", styleSheet: styles['footerLink']),
              ],
            ),
          ],
        ),
        DCFView(
          layout: layouts['footerBottom'],
          children: [
            DCFText(
              content: "© 2025 DotCorr. All rights reserved.",
              textProps: DCFTextProps(fontSize: 12),
              styleSheet: styles['footerCopyright'],
            ),
          ],
        ),
      ],
    );
  }
}
