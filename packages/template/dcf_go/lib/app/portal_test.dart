
import 'package:dcflight/dcflight.dart';

class PortalTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final portalVisible = useState<bool>(false);

    return DCFScrollView(
      layout: LayoutProps(flex: 1, padding: 20),
      children: [
        DCFText(
          content: "🌀 Simple Portal Test",
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: "bold",
            color: Colors.black,
          ),
          layout: LayoutProps(marginBottom: 30, height: 30),
        ),

        // Toggle Button
        DCFButton(
          buttonProps: DCFButtonProps(
            title: portalVisible.state ? "Hide Portal Content" : "Show Portal Content",
          ),
          layout: LayoutProps(marginBottom: 30, height: 50),
          styleSheet: StyleSheet(
            backgroundColor: portalVisible.state ? Colors.red : Colors.green,
            borderRadius: 8,
          ),
          onPress: (v) {
            portalVisible.setState(!portalVisible.state);
          },
        ),

        // Component 1: Source Area
        SourceComponent(portalVisible: portalVisible.state),

        // Spacer
        DCFView(layout: LayoutProps(height: 40)),

        // Component 2: Target Container
        TargetComponent(),
      ],
    );
  }
}

/// Component 1: The source where portal content is defined
class SourceComponent extends StatelessComponent {
  final bool portalVisible;

  SourceComponent({super.key, required this.portalVisible});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        padding: 20,
        minHeight: 120,
      ),
      styleSheet: StyleSheet(
        backgroundColor: Colors.orange.shade100,
        borderRadius: 12,
        borderWidth: 2,
        borderColor: Colors.orange.shade300,
      ),
      children: [
        DCFText(
          content: "📤 Source Component",
          textProps: DCFTextProps(
            fontSize: 18,
            fontWeight: "bold",
            color: Colors.orange.shade800,
          ),
          layout: LayoutProps(marginBottom: 10, height: 22),
        ),
        DCFText(
          content: "Portal content is defined here but renders below:",
          textProps: DCFTextProps(
            fontSize: 14,
            color: Colors.orange.shade700,
          ),
          layout: LayoutProps(marginBottom: 15, height: 18),
        ),

        // Portal Component - teleports its children to the target
        if (portalVisible)
          DCFPortalHostWrapper(
           
            targetId: "test",
           
            children: [
               DCFView(
                layout: LayoutProps(padding: 15),
                styleSheet: StyleSheet(
                  backgroundColor: Colors.pink.shade200,
                  borderRadius: 8,
                  borderWidth: 2,
                  borderColor: Colors.pink.shade400,
                ),
                children: [
                 
                  DCFText(
                    content: "✨ I'm teleported content 2! ✨",
                    textProps: DCFTextProps(
                      fontSize: 16,
                      fontWeight: "bold",
                      color: Colors.green.shade800,
                    ),
                    layout: LayoutProps(marginBottom: 8, height: 20),
                  ),
                  DCFText(
                    content: "I was defined in the Source Component but I appear in the Target Component below!",
                    textProps: DCFTextProps(
                      fontSize: 13,
                      color: Colors.pink.shade700,
                    ),
                    layout: LayoutProps(height: 32),
                  ),
                ],
              ),
              DCFView(
                layout: LayoutProps(padding: 15),
                styleSheet: StyleSheet(
                  backgroundColor: Colors.green.shade200,
                  borderRadius: 8,
                  borderWidth: 2,
                  borderColor: Colors.green.shade400,
                ),
                children: [
                  // DCFView(),
                  DCFText(
                    content: "✨ I'm teleported content! ✨",
                    textProps: DCFTextProps(
                      fontSize: 16,
                      fontWeight: "bold",
                      color: Colors.green.shade800,
                    ),
                    layout: LayoutProps(marginBottom: 8, height: 20),
                  ),
                  DCFText(
                    content: "I was defined in the Source Component but I appear in the Target Component below!",
                    textProps: DCFTextProps(
                      fontSize: 13,
                      color: Colors.green.shade700,
                    ),
                    layout: LayoutProps(height: 32),
                  ),
                ],
              ),
              
            ],
          ),

        if (!portalVisible)
          DCFText(
            content: "Portal is hidden. Click the toggle button to see the teleportation!",
            textProps: DCFTextProps(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            layout: LayoutProps(height: 18),
          ),
      ],
    );
  }
}

/// Component 2: The target where portaled content appears
class TargetComponent extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        padding: 20,
        minHeight: 120,
      ),
    children: [DCFPortalReceiverWrapper(targetId: "test")]
    );
  }
}
