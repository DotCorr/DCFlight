import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  DCFlight.setLogLevel(DCFLogLevel.debug);

  await DCFlight.start(app: MyTabApp());
}

// class MyStackApp extends StatefulComponent {
//   @override
//   DCFComponentNode render() {
//     final count = useState(0);
//     return DCFView(
//       // styleSheet: DCFStyleSheet(backgroundColor: Colors.red),
//       layout: DCFLayout(
//         flex: 1,
//         alignItems: YogaAlign.center,
//         justifyContent: YogaJustifyContent.center,
//         alignContent: YogaAlign.center,
//         paddingTop: 120,
//       ),
//       children: [
//         DCFView(
//           styleSheet: DCFStyleSheet(backgroundColor: Colors.green),
//           layout: DCFLayout(height: 500),
//           children: [
//             DCFText(
//               content: "Text example ${count.state}",
//               textProps: DCFTextProps(
//                 fontSize: 20,
//                 color: Colors.black,
//                 // textAlign: ,
//               ),
//             ),
//             DCFButton(
//               buttonProps: DCFButtonProps(title: "increment counter"),
//               onPress: (v) {
//                 print("Button pressed");
//                 print("Current count: ${count.state}");
//                 count.setState(count.state + 1);
//                 print("New count: ${count.state}");
//               },
//             ),
//           ],
//         ),
//         DCFView(
//           styleSheet: DCFStyleSheet(backgroundColor: Colors.orange),
//           children: [
//             DCFButton(
//               buttonProps: DCFButtonProps(title: "increment counter"),
//               onPress: (v) {
//                 print("Button pressed");
//                 print("Current count: ${count.state}");
//                 count.setState(count.state + 1);
//                 print("New count: ${count.state}");
//               },
//             ),
//             DCFButton(
//               buttonProps: DCFButtonProps(title: "increment counter"),
//               onPress: (v) {
//                 print("Button pressed");
//                 print("Current count: ${count.state}");
//                 count.setState(count.state + 1);
//                 print("New count: ${count.state}");
//               },
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   @override
//   List<Object?> get props => [];
// }

class MyTabApp extends DCFStatefulComponent {
  @override
  List<Object?> get props => [];

  @override
  DCFComponentNode render() {
    return DCFFragment(
      children: [
        DCFNestedNavigationRoot(
          selectedIndex: 0,
          tabRoutes: ["test1","test2","test2"],
          tabRoutesRegistryComponents: [],
          subRoutesRegistryComponents: [],
        ),
      ],
    );
  }
}
