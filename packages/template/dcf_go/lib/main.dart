import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  await DCFlight.go(app: LifecycleTestApp());
}

/// Simple test app to verify all lifecycle methods and hooks work correctly
class LifecycleTestApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    final showChild = useState<bool>(true);
    
    return DCFSafeArea(
      layout: DCFLayout(
        padding: 20,
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFTheme.current.backgroundColor,
      ),
      children: [
        // Test component that uses all lifecycle methods and hooks
        showChild.state
            ? LifecycleTestComponent(
                count: count.state,
              )
            : DCFText(
                content: 'Component unmounted',
                textProps: DCFTextProps(fontSize: 16),
              ),
        
        DCFButton(
          buttonProps: DCFButtonProps(title: "Count: ${count.state}"),
          onPress: (data) => count.setState(count.state + 1),
          layout: DCFLayout(marginTop: 20),
        ),
        
        DCFButton(
          buttonProps: DCFButtonProps(
            title: showChild.state ? "Unmount Component" : "Mount Component",
          ),
          onPress: (data) => showChild.setState(!showChild.state),
          layout: DCFLayout(marginTop: 10),
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [];
}

/// Component that tests all lifecycle methods and hooks
class LifecycleTestComponent extends DCFStatefulComponent {
  final int count;
  
  LifecycleTestComponent({
    required this.count,
    super.key,
  });
  
  @override
  List<Object?> get props => [count, key];
  
  @override
  DCFComponentNode render() {
    // Test useState hook
    final internalCount = useState<int>(0);
    final effectCount = useState<int>(0);
    final layoutEffectCount = useState<int>(0);
    final insertionEffectCount = useState<int>(0);
    
    // Test useEffect - runs after render
    useEffect(() {
      print('✅ useEffect: Running effect (count: $count, internalCount: ${internalCount.state})');
      effectCount.setState(effectCount.state + 1);
      
      // Cleanup function
      return () {
        print('🧹 useEffect: Cleanup called');
      };
    }, dependencies: [count, internalCount.state]);
    
    // Test useLayoutEffect - runs after layout
    useLayoutEffect(() {
      print('✅ useLayoutEffect: Running layout effect');
      layoutEffectCount.setState(layoutEffectCount.state + 1);
      
      return () {
        print('🧹 useLayoutEffect: Cleanup called');
      };
    }, dependencies: [count]);
    
    // Test useInsertionEffect - runs after insertion
    useInsertionEffect(() {
      print('✅ useInsertionEffect: Running insertion effect');
      insertionEffectCount.setState(insertionEffectCount.state + 1);
      
      return () {
        print('🧹 useInsertionEffect: Cleanup called');
      };
    }, dependencies: [count]);
    
    // Test useRef - returns RefObject directly
    final textRef = useRef<String>('Initial ref value');
    
    return DCFView(
      layout: DCFLayout(
        padding: 20,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.blue.withOpacity(0.1),
        borderColor: DCFColors.blue,
        borderWidth: 2,
        borderRadius: 12,
      ),
      children: [
        DCFText(
          content: "Lifecycle Test Component",
          textProps: DCFTextProps(
            fontSize: 20,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
        ),
        
        DCFText(
          content: "Props count: $count",
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
          layout: DCFLayout(marginTop: 10),
        ),
        
        DCFText(
          content: "Internal count: ${internalCount.state}",
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
          layout: DCFLayout(marginTop: 5),
        ),
        
        DCFText(
          content: "useEffect runs: ${effectCount.state}",
          textProps: DCFTextProps(fontSize: 14),
          styleSheet: DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
          layout: DCFLayout(marginTop: 10),
        ),
        
        DCFText(
          content: "useLayoutEffect runs: ${layoutEffectCount.state}",
          textProps: DCFTextProps(fontSize: 14),
          styleSheet: DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
          layout: DCFLayout(marginTop: 5),
        ),
        
        DCFText(
          content: "useInsertionEffect runs: ${insertionEffectCount.state}",
          textProps: DCFTextProps(fontSize: 14),
          styleSheet: DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
          layout: DCFLayout(marginTop: 5),
        ),
        
        DCFText(
          content: "Ref value: ${textRef.current}",
          textProps: DCFTextProps(fontSize: 14),
          styleSheet: DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
          layout: DCFLayout(marginTop: 10),
        ),
        
        DCFButton(
          buttonProps: DCFButtonProps(title: "Increment Internal"),
          onPress: (data) => internalCount.setState(internalCount.state + 1),
          layout: DCFLayout(marginTop: 15),
        ),
        
        DCFButton(
          buttonProps: DCFButtonProps(title: "Update Ref"),
          onPress: (data) {
            textRef.current = 'Updated at ${DateTime.now().millisecondsSinceEpoch}';
            scheduleUpdate(); // Manually trigger update to show ref change
          },
          layout: DCFLayout(marginTop: 10),
        ),
      ],
    );
  }
  
  @override
  void componentDidMount() {
    super.componentDidMount();
    print('✅ componentDidMount: LifecycleTestComponent mounted');
  }
  
  @override
  void componentDidUpdate(Map<String, dynamic> prevProps) {
    super.componentDidUpdate(prevProps);
    print('✅ componentDidUpdate: LifecycleTestComponent updated');
    print('   Previous count: ${prevProps['count'] ?? 'N/A'}, New count: $count');
  }
  
  @override
  void componentWillUnmount() {
    super.componentWillUnmount();
    print('✅ componentWillUnmount: LifecycleTestComponent unmounting');
  }
}
