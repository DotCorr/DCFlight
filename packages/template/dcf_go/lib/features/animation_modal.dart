/*
 * COMPONENT RE-RENDER TEST
 * Testing if ALL components re-render on state changes
 * Using the RECOMMENDED developer pattern with EquatableMixin
 */

import "package:dcflight/dcflight.dart";

class ComponentRerenderTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final counterState = useState(0);

    // 🔍 DEBUG TEST: Create two identical components and test equality
    final test1 = TestComponent1(componentId: "test", key: "test");
    final test2 = TestComponent1(componentId: "test", key: "test");
    
    print("🔍 DEBUG: test1 == test2: ${test1 == test2}");
    print("🔍 DEBUG: test1.props: ${test1.props}");
    print("🔍 DEBUG: test2.props: ${test2.props}");
    print("🔍 DEBUG: test1.runtimeType == test2.runtimeType: ${test1.runtimeType == test2.runtimeType}");
    print("🔍 DEBUG: test1.key == test2.key: ${test1.key == test2.key}");

    return DCFSafeArea(
      children: [
        // Test button that changes state
        DCFButton(
          buttonProps: DCFButtonProps(title: "Increment Counter: ${counterState.state}"),
          layout: LayoutProps(height: 50, width: 300, marginBottom: 20),
          styleSheet: StyleSheet(backgroundColor: Colors.pink, borderRadius: 25),
          onPress: (v) {
            print("🔥 COUNTER BUTTON PRESSED - Setting state to ${counterState.state + 1}");
            counterState.setState(counterState.state + 1);
            print("🔥 STATE UPDATE COMPLETE");
          },
        ),

        // Test Components using developer pattern
        TestComponent1(componentId: "component_1"),
        TestComponent2(componentId: "component_2"),
        TestComponent3(componentId: "component_3", counter: counterState.state),
        TestComponent4(componentId: "component_4"),
      ],
    );
  }
}

// ============================================================================
// TEST COMPONENTS - Using EquatableMixin (Recommended Developer Pattern)
// ============================================================================

/// Test Component 1 - Static, no dependencies
class TestComponent1 extends StatelessComponent with EquatableMixin {
  final String componentId;

  TestComponent1({required this.componentId, super.key});

  @override
  DCFComponentNode render() {
    // This should NOT log when counter changes
    print("🟦 TestComponent1 ($componentId) RENDERED");

    return DCFView(
      children: [
        DCFText(
          content: "Component 1 - Static",
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.white,
            textAlign: "center",
          ),
        ),
      ],
      layout: LayoutProps(
        height: 60,
        width: 200,
        marginBottom: 10,
        padding: 10,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: Colors.blue,
        borderRadius: 10,
      ),
    );
  }

  // ✅ Developer pattern: Just list the props that affect rendering
  @override
  List<Object?> get props => [componentId, key];
}

/// Test Component 2 - Static, different color to track independently
class TestComponent2 extends StatelessComponent with EquatableMixin {
  final String componentId;

  TestComponent2({required this.componentId, super.key});

  @override
  DCFComponentNode render() {
    // This should NOT log when counter changes
    print("🟩 TestComponent2 ($componentId) RENDERED");

    return DCFView(
      children: [
        DCFText(
          content: "Component 2 - Static",
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.white,
            textAlign: "center",
          ),
        ),
      ],
      layout: LayoutProps(
        height: 60,
        width: 200,
        marginBottom: 10,
        padding: 10,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: Colors.green,
        borderRadius: 10,
      ),
    );
  }

  // ✅ Developer pattern: Just list the props that affect rendering
  @override
  List<Object?> get props => [componentId, key];
}

/// Test Component 3 - SHOULD re-render because it depends on counter
class TestComponent3 extends StatelessComponent with EquatableMixin {
  final String componentId;
  final int counter;

  TestComponent3({required this.componentId, required this.counter, super.key});

  @override
  DCFComponentNode render() {
    // This SHOULD log when counter changes
    print("🟪 TestComponent3 ($componentId) RENDERED with counter: $counter");

    return DCFView(
      children: [
        DCFText(
          content: "Component 3 - Counter: $counter",
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.white,
            textAlign: "center",
          ),
        ),
      ],
      layout: LayoutProps(
        height: 60,
        width: 200,
        marginBottom: 10,
        padding: 10,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: Colors.purple,
        borderRadius: 10,
      ),
    );
  }

  // ✅ Developer pattern: Include counter since it affects rendering
  @override
  List<Object?> get props => [componentId, counter, key];
}

/// Test Component 4 - Stateful component to test stateful behavior
class TestComponent4 extends StatefulComponent {
  final String componentId;

  TestComponent4({required this.componentId, super.key});

  @override
  DCFComponentNode render() {
    // This should NOT log when parent counter changes
    print("🟨 TestComponent4 ($componentId) RENDERED");

    final internalState = useState(0);

    return DCFView(
      children: [
        DCFText(
          content: "Component 4 - Internal: ${internalState.state}",
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.black,
            textAlign: "center",
          ),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "+"),
          layout: LayoutProps(height: 30, width: 40, marginTop: 5),
          styleSheet: StyleSheet(backgroundColor: Colors.orange, borderRadius: 5),
          onPress: (v) {
            print("🟨 TestComponent4 internal button pressed");
            internalState.setState(internalState.state + 1);
          },
        ),
      ],
      layout: LayoutProps(
        height: 100,
        width: 200,
        marginBottom: 10,
        padding: 10,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: Colors.yellow,
        borderRadius: 10,
      ),
    );
  }
}

