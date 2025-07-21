import 'package:dcflight/dcflight.dart';

class Profile extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final actionSheetVisible = useState<bool>(false);
    final alertVisible = useState<bool>(false);
    final textInputAlertVisible = useState<bool>(false);
    final loginAlertVisible = useState<bool>(false);
    final toggleValue = useState<bool>(false);
    final checkboxValue = useState<bool>(false);

    // Command states for demonstrating command pattern
    final scrollCommand = useState<ScrollViewCommand?>(null);

    return DCFScrollView(
      // ✅ Command pattern demonstration for ScrollView
      command: scrollCommand.state,
      layout: LayoutProps(flex: 1, padding: 16.0),
      onScroll: (v) {
        if (scrollCommand.state != null) {
          Future.microtask(() => scrollCommand.setState(null));
        }
      },
      children: [
        DCFText(
          content: "🚀 DCF Primitives Test",
          textProps: DCFTextProps(fontSize: 24, fontWeight: DCFFontWeight.bold),
          layout: LayoutProps(marginBottom: 20.0, height: 30.0),
        ),

        // Modal Tests
        DCFText(
          content: "Native Modal Components",
          textProps: DCFTextProps(
            fontSize: 18,
            fontWeight: DCFFontWeight.semibold,
          ),
          layout: LayoutProps(marginBottom: 16.0, height: 25.0),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Show Action Sheet"),
          layout: LayoutProps(marginBottom: 12, height: 44),
          styleSheet: StyleSheet(
            backgroundColor: Colors.purple,
            borderColor: Colors.purple,
            borderWidth: 1,
            borderRadius: 8,
          ),
          onPress: (v) {
            actionSheetVisible.setState(true);
          },
        ),

        // ✅ Command demonstration button
        DCFButton(
          buttonProps: DCFButtonProps(title: "Scroll to Bottom"),
          layout: LayoutProps(marginBottom: 20, height: 44),
          styleSheet: StyleSheet(backgroundColor: Colors.teal, borderRadius: 8),
          onPress: (v) {
            // ✅ Using scroll command pattern
            scrollCommand.setState(
              ScrollViewCommand(
                scrollToBottom: const ScrollToBottomCommand(animated: true),
              ),
            );
          },
        ),

        // Toggle/Switch Tests
        DCFText(
          content: "Toggle & Checkbox",
          textProps: DCFTextProps(
            fontSize: 18,
            fontWeight: DCFFontWeight.semibold,
            color: Colors.black87,
          ),
          layout: LayoutProps(marginBottom: 16, height: 25),
        ),

        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row,
            alignItems: YogaAlign.center,
            height: 44,
            marginBottom: 12,
          ),
          children: [
            DCFToggle(
              layout: LayoutProps(width: 60, height: 32),
              value: toggleValue.state,
              onValueChange: (data) {
                toggleValue.setState(data['value'] as bool);
              },
              activeTrackColor: Colors.green,
              size: DCFToggleSize.medium,
            ),
            DCFText(
              content: "Toggle: ${toggleValue.state ? 'ON' : 'OFF'}",
              textProps: DCFTextProps(fontSize: 16, color: Colors.black87),
              layout: LayoutProps(marginLeft: 12, flex: 1, height: 20),
            ),
          ],
        ),

        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row,
            alignItems: YogaAlign.center,
            height: 44,
            marginBottom: 20,
          ),
          children: [
            DCFCheckbox(
              layout: LayoutProps(width: 24, height: 24),
              checked: checkboxValue.state,
              onValueChange: (data) {
                checkboxValue.setState(data['value'] as bool);
              },
              activeColor: Colors.blue,
              size: DCFCheckboxSize.medium,
            ),
            DCFText(
              content:
                  "Checkbox: ${checkboxValue.state ? 'Checked' : 'Unchecked'}",
              textProps: DCFTextProps(fontSize: 16, color: Colors.black87),
              layout: LayoutProps(marginLeft: 12, flex: 1),
            ),
          ],
        ),

        // Alert Tests
        DCFText(
          content: "Alert Components",
          textProps: DCFTextProps(
            fontSize: 18,
            fontWeight: DCFFontWeight.semibold,
            color: Colors.black87,
          ),
          layout: LayoutProps(marginBottom: 16, height: 25),
        ),

        DCFSpinner(
          animating: true,
          color: Colors.amber,
          style: DCFSpinnerStyle.medium,
          layout: LayoutProps(height: 60, width: 60),
          styleSheet: StyleSheet(backgroundColor: Colors.blue),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Simple Alert"),
          layout: LayoutProps(marginBottom: 12, height: 44),
          styleSheet: StyleSheet(
            backgroundColor: Colors.orange,
            borderRadius: 8,
          ),
          onPress: (v) {
            alertVisible.setState(true);
          },
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Action Sheet"),
          layout: LayoutProps(marginBottom: 12, height: 44),
          styleSheet: StyleSheet(
            backgroundColor: Colors.purple,
            borderRadius: 8,
          ),
          onPress: (v) {
            actionSheetVisible.setState(true);
          },
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Text Input Alert"),
          layout: LayoutProps(marginBottom: 12, height: 44),
          styleSheet: StyleSheet(
            backgroundColor: Colors.green,
            borderRadius: 8,
          ),
          onPress: (v) {
            textInputAlertVisible.setState(true);
          },
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Login Alert"),
          layout: LayoutProps(marginBottom: 20, height: 44),
          styleSheet: StyleSheet(backgroundColor: Colors.teal, borderRadius: 8),
          onPress: (v) {
            loginAlertVisible.setState(true);
          },
        ),

        // Native DCFModal - true native modal presentation

        // Alert Component
        DCFAlert(
          adaptive: false,
          visible: alertVisible.state,
          title: "Test Alert",
          message: "This is a test alert message with custom actions!",
          style: DCFAlertStyle.alert,
          actions: [
            DCFAlertAction(
              title: 'Cancel',
              style: DCFAlertActionStyle.cancel,
              handler: 'cancel',
            ),
            DCFAlertAction(
              title: 'OK',
              style: DCFAlertActionStyle.defaultStyle,
              handler: 'confirm',
            ),
          ],
          dismissible: true,
          onShow: (data) {},
          onActionPress: (data) {
            if (data['handler'] == 'cancel') {
              alertVisible.setState(false);
            } else if (data['handler'] == 'confirm') {
              alertVisible.setState(false);
            }
          },
          onDismiss: (data) {
            alertVisible.setState(false);
          },
        ),

        // Text Input Alert
        DCFAlert(
          visible: textInputAlertVisible.state,
          title: "Enter Your Name",
          message: "Please enter your full name:",
          style: DCFAlertStyle.alert,
          textFields: [
            DCFAlertTextField(
              placeholder: "Full Name",
              keyboardType: DCFKeyboardType.defaultType,
            ),
          ],
          actions: [
            DCFAlertAction(
              title: 'Cancel',
              style: DCFAlertActionStyle.cancel,
              handler: 'cancel',
            ),
            DCFAlertAction(
              title: 'Save',
              style: DCFAlertActionStyle.defaultStyle,
              handler: 'confirm',
            ),
          ],
          onActionPress: (data) {
            if (data['handler'] == 'confirm') {
              List<String> textValues = List<String>.from(
                data['textFieldValues'] ?? [],
              );
              if (textValues.isNotEmpty) {}
            }
            textInputAlertVisible.setState(false);
          },
          onShow: (data) {},
          onDismiss: (data) {
            textInputAlertVisible.setState(false);
          },
          onTextFieldChange: (data) {},
        ),

        // Login Alert
        DCFAlert(
          visible: loginAlertVisible.state,
          title: "Login Required",
          message: "Please enter your credentials:",
          style: DCFAlertStyle.alert,

          textFields: [
            DCFAlertTextField(
              placeholder: "Email",
              keyboardType: DCFKeyboardType.emailAddress,
              autoCapitalization: DCFAutoCapitalizationType.none,
              textContentType: DCFTextContentType.username,
            ),
            DCFAlertTextField.secure(
              placeholder: "Password",
              textContentType: DCFTextContentType.password,
            ),
          ],
          actions: [
            DCFAlertAction(
              title: 'Cancel',
              style: DCFAlertActionStyle.cancel,
              handler: 'cancel',
            ),
            DCFAlertAction(
              title: 'Sign In',
              style: DCFAlertActionStyle.defaultStyle,
              handler: 'login',
            ),
          ],
          onActionPress: (data) {
            if (data['handler'] == 'login') {
              List<String> textValues = List<String>.from(
                data['textFieldValues'] ?? [],
              );
              if (textValues.length >= 2) {}
            }
            loginAlertVisible.setState(false);
          },
          onShow: (data) {},
          onDismiss: (data) {
            loginAlertVisible.setState(false);
          },
          onTextFieldChange: (data) {},
        ),

        // Action Sheet Alert Component
        DCFAlert(
          visible: actionSheetVisible.state,
          title: "Choose Action",
          message:
              "What would you like to do? Select an action from the list below:",
          style: DCFAlertStyle.actionSheet,
          actions: [
            DCFAlertAction(
              title: 'Edit',
              style: DCFAlertActionStyle.defaultStyle,
              handler: 'edit',
            ),
            DCFAlertAction(
              title: 'Share',
              style: DCFAlertActionStyle.defaultStyle,
              handler: 'share',
            ),
            DCFAlertAction(
              title: 'Delete',
              style: DCFAlertActionStyle.destructive,
              handler: 'delete',
            ),
            DCFAlertAction(
              title: 'Cancel',
              style: DCFAlertActionStyle.cancel,
              handler: 'cancel',
            ),
          ],
          dismissible: true,
          onShow: (data) {},
          onActionPress: (data) {
            actionSheetVisible.setState(false);

            switch (data['handler']) {
              case 'edit':
                break;
              case 'share':
                break;
              case 'delete':
                break;
              case 'cancel':
                break;
            }
          },
          onDismiss: (data) {
            actionSheetVisible.setState(false);
          },
        ),
      ],
    );
  }
}
