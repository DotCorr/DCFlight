import 'package:dcflight/dcflight.dart';

/// Screen Utilities Test Component
/// Displays all ScreenUtilities values and verifies they update reactively
class ScreenUtilitiesTest extends DCFStatefulComponent {
  final VoidCallback? onClose;
  
  ScreenUtilitiesTest({this.onClose, super.key});

  @override
  DCFComponentNode render() {
    final screenUtils = ScreenUtilities.instance;
    
    // Use state to track values and update when dimensions change
    final screenWidth = useState<double>(screenUtils.screenWidth);
    final screenHeight = useState<double>(screenUtils.screenHeight);
    final scaleFactor = useState<double>(screenUtils.scaleFactor);
    final fontScale = useState<double>(screenUtils.fontScale);
    final statusBarHeight = useState<double>(screenUtils.statusBarHeight);
    final safeAreaTop = useState<double>(screenUtils.safeAreaTop);
    final safeAreaBottom = useState<double>(screenUtils.safeAreaBottom);
    final safeAreaLeft = useState<double>(screenUtils.safeAreaLeft);
    final safeAreaRight = useState<double>(screenUtils.safeAreaRight);
    final isLandscape = useState<bool>(screenUtils.isLandscape);
    final isPortrait = useState<bool>(screenUtils.isPortrait);
    final previousWidth = useState<double>(screenUtils.previousWidth);
    final previousHeight = useState<double>(screenUtils.previousHeight);
    final wasOrientationChange = useState<bool>(screenUtils.wasOrientationChange);
    final wasWindowResize = useState<bool>(screenUtils.wasWindowResize);
    final updateCount = useState<int>(0);
    
    // Listen to dimension changes and update all values
    useEffect(() {
      final subscription = screenUtils.dimensionChanges.listen((_) {
        screenWidth.setState(screenUtils.screenWidth);
        screenHeight.setState(screenUtils.screenHeight);
        scaleFactor.setState(screenUtils.scaleFactor);
        fontScale.setState(screenUtils.fontScale);
        statusBarHeight.setState(screenUtils.statusBarHeight);
        safeAreaTop.setState(screenUtils.safeAreaTop);
        safeAreaBottom.setState(screenUtils.safeAreaBottom);
        safeAreaLeft.setState(screenUtils.safeAreaLeft);
        safeAreaRight.setState(screenUtils.safeAreaRight);
        isLandscape.setState(screenUtils.isLandscape);
        isPortrait.setState(screenUtils.isPortrait);
        previousWidth.setState(screenUtils.previousWidth);
        previousHeight.setState(screenUtils.previousHeight);
        wasOrientationChange.setState(screenUtils.wasOrientationChange);
        wasWindowResize.setState(screenUtils.wasWindowResize);
        updateCount.setState(updateCount.state + 1);
        print('✅ ScreenUtilities: Dimension change detected! Update count: ${updateCount.state + 1}');
      });
      
      // Immediately refresh values on mount
      screenWidth.setState(screenUtils.screenWidth);
      screenHeight.setState(screenUtils.screenHeight);
      scaleFactor.setState(screenUtils.scaleFactor);
      fontScale.setState(screenUtils.fontScale);
      statusBarHeight.setState(screenUtils.statusBarHeight);
      safeAreaTop.setState(screenUtils.safeAreaTop);
      safeAreaBottom.setState(screenUtils.safeAreaBottom);
      safeAreaLeft.setState(screenUtils.safeAreaLeft);
      safeAreaRight.setState(screenUtils.safeAreaRight);
      isLandscape.setState(screenUtils.isLandscape);
      isPortrait.setState(screenUtils.isPortrait);
      previousWidth.setState(screenUtils.previousWidth);
      previousHeight.setState(screenUtils.previousHeight);
      wasOrientationChange.setState(screenUtils.wasOrientationChange);
      wasWindowResize.setState(screenUtils.wasWindowResize);
      
      return subscription.cancel;
    }, dependencies: []);
    
    return DCFScrollView(
      layout: DCFLayout(width: '100%', height: '100%'),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.white),
      scrollContent: [
        DCFView(
          layout: DCFLayout(
            width: '100%',
            padding: 24,
            gap: 24,
          ),
          children: [
            // Header
            DCFView(
              layout: DCFLayout(
                width: '100%',
                flexDirection: DCFFlexDirection.row,
                justifyContent: DCFJustifyContent.spaceBetween,
                alignItems: DCFAlign.center,
                marginBottom: 16,
              ),
              children: [
                DCFText(
                  content: 'Screen Utilities Test',
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
                if (onClose != null)
                  DCFTouchableOpacity(
                    onPress: (data) => onClose!(),
                    layout: DCFLayout(padding: 8),
                    styleSheet: DCFStyleSheet(
                      backgroundColor: DCFColors.red,
                      borderRadius: 8,
                    ),
                    children: [
                      DCFText(
                        content: 'Close',
                        textProps: DCFTextProps(
                          fontSize: 14,
                          fontWeight: DCFFontWeight.bold,
                        ),
                        styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                      ),
                    ],
                  ),
              ],
            ),
            
            // Update count
            DCFView(
              layout: DCFLayout(
                width: '100%',
                padding: 16,
                marginBottom: 16,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.gray100,
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'Update Count: ${updateCount.state}',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
            
            // Screen Dimensions
            _buildSection('Screen Dimensions', [
              _buildRow('Width', '${screenWidth.state.toStringAsFixed(1)}px'),
              _buildRow('Height', '${screenHeight.state.toStringAsFixed(1)}px'),
              _buildRow('Previous Width', '${previousWidth.state.toStringAsFixed(1)}px'),
              _buildRow('Previous Height', '${previousHeight.state.toStringAsFixed(1)}px'),
            ]),
            
            // Scale & Font
            _buildSection('Scale & Font', [
              _buildRow('Scale Factor', scaleFactor.state.toStringAsFixed(2)),
              _buildRow('Font Scale', fontScale.state.toStringAsFixed(2)),
            ]),
            
            // Status Bar
            _buildSection('Status Bar', [
              _buildRow('Status Bar Height', '${statusBarHeight.state.toStringAsFixed(1)}px'),
            ]),
            
            // Safe Area
            _buildSection('Safe Area Insets', [
              _buildRow('Top', '${safeAreaTop.state.toStringAsFixed(1)}px'),
              _buildRow('Bottom', '${safeAreaBottom.state.toStringAsFixed(1)}px'),
              _buildRow('Left', '${safeAreaLeft.state.toStringAsFixed(1)}px'),
              _buildRow('Right', '${safeAreaRight.state.toStringAsFixed(1)}px'),
            ]),
            
            // Orientation
            _buildSection('Orientation', [
              _buildRow('Is Landscape', isLandscape.state.toString()),
              _buildRow('Is Portrait', isPortrait.state.toString()),
              _buildRow('Was Orientation Change', wasOrientationChange.state.toString()),
              _buildRow('Was Window Resize', wasWindowResize.state.toString()),
            ]),
            
            // Refresh Button
            DCFTouchableOpacity(
              onPress: (data) async {
                print('🔄 ScreenUtilities: Manually refreshing dimensions...');
                await screenUtils.refreshDimensions();
                print('✅ ScreenUtilities: Refresh completed');
              },
              layout: DCFLayout(
                padding: 16,
                marginTop: 16,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.blue,
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'Refresh Dimensions',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
  
  DCFComponentNode _buildSection(String title, List<DCFComponentNode> rows) {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        marginBottom: 24,
        padding: 16,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.gray50,
        borderRadius: 8,
      ),
      children: [
        DCFView(
          layout: DCFLayout(marginBottom: 12),
          children: [
            DCFText(
              content: title,
              textProps: DCFTextProps(
                fontSize: 18,
                fontWeight: DCFFontWeight.bold,
              ),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
            ),
          ],
        ),
        ...rows,
      ],
    );
  }
  
  DCFComponentNode _buildRow(String label, String value) {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        flexDirection: DCFFlexDirection.row,
        justifyContent: DCFJustifyContent.spaceBetween,
        alignItems: DCFAlign.center,
        paddingVertical: 8,
      ),
      children: [
        DCFText(
          content: label,
          textProps: DCFTextProps(fontSize: 14),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
        ),
        DCFText(
          content: value,
          textProps: DCFTextProps(
            fontSize: 14,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
        ),
      ],
    );
  }
}
