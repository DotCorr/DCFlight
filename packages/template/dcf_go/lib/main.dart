import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';
import 'package:o3d/o3d.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator, AlwaysStoppedAnimation, Color, Material, Theme, ThemeData;

void main() async {
  DCFLogger.setLevel(DCFLogLevel.info);
  DCFLogger.info('Starting Globe Demo App...', 'App');
  
  await DCFlight.go(app: GlobeDemoApp());
}

class GlobeDemoApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final isRotationEnabled = useState<bool>(true);
    
    // Use useRef to store the O3D controller - persists across renders
    final controllerRef = useRef<O3DController?>(null);
    
    // Initialize controller synchronously during render if not already initialized
    if (controllerRef.current == null) {
      controllerRef.current = O3DController();
      print('🌍 O3D: Controller initialized');
    }
    
    // Update auto-rotate when enabled state changes
    useEffect(() {
      if (controllerRef.current != null) {
        if (isRotationEnabled.state) {
          // Auto-rotate is handled by O3D's autoRotate property
          print('🌍 O3D: Auto-rotate enabled');
        } else {
          print('🌍 O3D: Auto-rotate disabled');
        }
      }
      return null;
    }, dependencies: [isRotationEnabled.state]);
    
    return DCFView(
      layout: DCFLayout(
        paddingTop: 100,
        flex: 1,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.black,
      ),
      children: [
       
        WidgetToDCFAdaptor.builder(
          widgetBuilder: () {
            final controller = controllerRef.current;
            print('🌍 O3D widgetBuilder called - controller: ${controller != null ? "exists" : "null"}, autoRotate: ${isRotationEnabled.state}');
            
            if (controller == null) {
              print('⚠️ O3D: Controller is null, showing loading indicator');
              return Container(
                color: DCFColors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(DCFColors.white),
                  ),
                ),
              );
            }
            
            print('✅ O3D: Controller exists, rendering O3D with network model');
            
            // O3D uses WebView internally - plugins are now registered with our custom engine
            // The widget will rebuild when isRotationEnabled changes (ValueKey ensures this)
            return 
              Container(
                  color: DCFColors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: O3D.network(
                    key: ValueKey('o3d_${isRotationEnabled.state}'),
                    src: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
                    controller: controller,
                    autoRotate: isRotationEnabled.state,
                    autoPlay: true,
                    backgroundColor: DCFColors.black,
              ),
            );
          },
          layout: DCFLayout(
            flex: 1,
            width: "100%",
            height: "100%",
          ),
          styleSheet: DCFStyleSheet(),
        ),
        
        // Controls Panel
        DCFView(
          layout: DCFLayout(
            width:'100%',
                flexWrap: DCFWrap.wrap,

            padding: 20,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFTheme.current.surfaceColor,
            borderRadius: 20,
            elevation: 10,
          ),
          children: [
            DCFText(
              content: "3D Model Controls",
              textProps: DCFTextProps(
                fontSize: 20,
                fontWeight: DCFFontWeight.bold,
              ),
              styleSheet: DCFStyleSheet(
                primaryColor: DCFTheme.current.textColor,
              ),
              layout: DCFLayout(
                marginBottom: 15,
              ),
            ),
            
            // Auto-rotate toggle
            DCFView(
              layout: DCFLayout(
                marginHorizontal: 10,
                width: "100%",
                flexDirection: DCFFlexDirection.row,
                justifyContent: DCFJustifyContent.spaceBetween,
                alignItems: DCFAlign.center,
                marginBottom: 15,
              ),
              children: [
                DCFText(
                  content: "Auto-Rotate:",
                  textProps: DCFTextProps(
                    fontSize: 16,
                  ),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFTheme.current.textColor,
                  ),
                  layout: DCFLayout(marginRight: 10),
                ),
                DCFToggle(
                  value: isRotationEnabled.state,
                  onValueChange: (DCFToggleValueData data) {
                    isRotationEnabled.setState(data.value);
                  },
                ),
              ],
            ),
            
            // Info
            DCFView(
              layout: DCFLayout(
                padding: 10,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: const Color(0x3300FF00),
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: "Using WidgetToDCFAdaptor\nO3D 3D Model Viewer\nInteractive glTF/GLB rendering",
                  textProps: DCFTextProps(
                    fontSize: 12,
                  ),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFColors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
