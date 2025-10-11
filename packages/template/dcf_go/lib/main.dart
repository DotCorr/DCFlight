import 'package:dcf_go/config/navigation/stack_registry.dart';
import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';
import 'dart:math';

void main() async {
  await DCFlight.go(app: TodoApp());
}

class TodoApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final todos = useState<List<String>>([]);
    final input = useState('');
    
    return DCFView(
      layout: DCFLayout(
        flex: 1,
        padding: 20,
        gap: 10,
        alignItems: YogaAlign.center,
        justifyContent: YogaJustifyContent.center,
      ),
      children: [
        DCFTextInput(
          value: input.state,
          onChangeText: (text) {
            input.setState(text);
          },
        ),
        DCFText(content: todos.toString(), textProps: DCFTextProps(color: Colors.black)),
        DCFButton(
          buttonProps: DCFButtonProps(title: 'Add Todo'),
          onPress: (v) {
            if (input.state.isNotEmpty) {
              todos.setState([...todos.state, input.state]);
              input.setState('');
            }
          },
        ),
        ...todos.state.map((todo) => 
          DCFText(

            content: todo,
            textProps: DCFTextProps(fontSize: 16,color: Colors.black),
          )
        ),
      ],
    );
  }
  
  @override
  List<Object?> get props => [];
}