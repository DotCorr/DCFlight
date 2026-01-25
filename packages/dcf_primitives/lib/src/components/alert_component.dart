/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';

/// Alert text field configuration with full parity to DCFTextInput
class DCFAlertTextField {
  final String? placeholder;
  final String? text;
  final String? defaultValue;
  /// NOTE: placeholderTextColor removed - use StyleSheet.secondaryColor instead
  
  final bool secureTextEntry;
  
  final DCFKeyboardType keyboardType;
  final DCFAutoCapitalizationType autoCapitalization;
  final DCFReturnKeyType returnKeyType;
  final DCFTextContentType textContentType;
  
  final bool autoCorrect;
  final bool autoFocus;
  final bool clearButtonMode;
  final bool clearTextOnFocus;
  final bool enablesReturnKeyAutomatically;
  final bool editable;
  final bool selectTextOnFocus;
  final bool spellCheck;
  
  final int? maxLength;
  final int? numberOfLines;
  final bool multiline;
  
  final String? textAlign;
  /// NOTE: textColor removed - use StyleSheet.primaryColor instead
  /// NOTE: selectionColor removed - use StyleSheet.accentColor instead
  final double? fontSize;
  final String? fontWeight;
  final String? fontFamily;

  const DCFAlertTextField({
    this.placeholder,
    this.text,
    this.defaultValue,
    // placeholderTextColor removed - use StyleSheet.secondaryColor
    
    this.secureTextEntry = false,
    
    this.keyboardType = DCFKeyboardType.defaultType,
    this.autoCapitalization = DCFAutoCapitalizationType.sentences,
    this.returnKeyType = DCFReturnKeyType.defaultReturn,
    this.textContentType = DCFTextContentType.none,
    
    this.autoCorrect = true,
    this.autoFocus = false,
    this.clearButtonMode = false,
    this.clearTextOnFocus = false,
    this.enablesReturnKeyAutomatically = false,
    this.editable = true,
    this.selectTextOnFocus = false,
    this.spellCheck = true,
    
    this.maxLength,
    this.numberOfLines = 1,
    this.multiline = false,
    
    this.textAlign,
    // textColor and selectionColor removed - use StyleSheet
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
  });

  const DCFAlertTextField.secure({
    this.placeholder,
    this.text,
    this.defaultValue,
    // placeholderTextColor removed - use StyleSheet.secondaryColor
    this.keyboardType = DCFKeyboardType.defaultType,
    this.autoCapitalization = DCFAutoCapitalizationType.none,
    this.returnKeyType = DCFReturnKeyType.defaultReturn,
    this.textContentType = DCFTextContentType.password,
    this.autoCorrect = false,
    this.autoFocus = false,
    this.clearButtonMode = false,
    this.clearTextOnFocus = false,
    this.enablesReturnKeyAutomatically = false,
    this.editable = true,
    this.selectTextOnFocus = false,
    this.spellCheck = false,
    this.maxLength,
    this.numberOfLines = 1,
    this.multiline = false,
    this.textAlign,
    // textColor and selectionColor removed - use StyleSheet
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
  }) : secureTextEntry = true;

  Map<String, dynamic> toMap() {
    return {
      'placeholder': placeholder,
      'text': text,
      'defaultValue': defaultValue,
      // placeholderTextColor removed - native components use StyleSheet.secondaryColor
      
      'secureTextEntry': secureTextEntry,
      
      'keyboardType': keyboardType.name,
      'autoCapitalization': autoCapitalization.name,
      'returnKeyType': returnKeyType.name,
      'textContentType': textContentType.name,
      
      'autoCorrect': autoCorrect,
      'autoFocus': autoFocus,
      'clearButtonMode': clearButtonMode,
      'clearTextOnFocus': clearTextOnFocus,
      'enablesReturnKeyAutomatically': enablesReturnKeyAutomatically,
      'editable': editable,
      'selectTextOnFocus': selectTextOnFocus,
      'spellCheck': spellCheck,
      
      'maxLength': maxLength,
      'numberOfLines': numberOfLines,
      'multiline': multiline,
      
      'textAlign': textAlign,
      // textColor and selectionColor removed - native components use StyleSheet
      'fontSize': fontSize,
      'fontWeight': fontWeight,
      'fontFamily': fontFamily,
    };
  }
  
  const DCFAlertTextField.email({
    this.placeholder = 'Email',
    this.text,
    this.defaultValue,
    // placeholderTextColor removed - use StyleSheet.secondaryColor
    this.returnKeyType = DCFReturnKeyType.next,
    this.autoFocus = false,
    this.clearButtonMode = true,
    this.clearTextOnFocus = false,
    this.enablesReturnKeyAutomatically = true,
    this.editable = true,
    this.selectTextOnFocus = false,
    this.spellCheck = false,
    this.maxLength,
    this.numberOfLines = 1,
    this.multiline = false,
    this.textAlign,
    // textColor and selectionColor removed - use StyleSheet
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
  }) : secureTextEntry = false,
       keyboardType = DCFKeyboardType.emailAddress,
       autoCapitalization = DCFAutoCapitalizationType.none,
       textContentType = DCFTextContentType.emailAddress,
       autoCorrect = false;
       
  const DCFAlertTextField.phone({
    this.placeholder = 'Phone Number',
    this.text,
    this.defaultValue,
    // placeholderTextColor removed - use StyleSheet.secondaryColor
    this.returnKeyType = DCFReturnKeyType.done,
    this.autoFocus = false,
    this.clearButtonMode = true,
    this.clearTextOnFocus = false,
    this.enablesReturnKeyAutomatically = true,
    this.editable = true,
    this.selectTextOnFocus = false,
    this.spellCheck = false,
    this.maxLength,
    this.numberOfLines = 1,
    this.multiline = false,
    this.textAlign,
    // textColor and selectionColor removed - use StyleSheet
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
  }) : secureTextEntry = false,
       keyboardType = DCFKeyboardType.phonePad,
       autoCapitalization = DCFAutoCapitalizationType.none,
       textContentType = DCFTextContentType.telephoneNumber,
       autoCorrect = false;
}

/// Alert action configuration
class DCFAlertAction {
  final String title;
  final DCFAlertActionStyle style;
  final String handler;
  final bool enabled;

  const DCFAlertAction({
    required this.title,
    this.style = DCFAlertActionStyle.defaultStyle,
    required this.handler,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'style': style.value,
      'handler': handler,
      'enabled': enabled,
    };
  }
}

/// Alert action styles
enum DCFAlertActionStyle {
  defaultStyle('default'),
  cancel('cancel'),
  destructive('destructive');

  const DCFAlertActionStyle(this.value);
  final String value;
}

/// Alert styles
enum DCFAlertStyle {
  alert('alert'),
  actionSheet('actionSheet');

  const DCFAlertStyle(this.value);
  final String value;
}

/// 🚀 DCF Alert Component
/// 
/// An alert/dialog component that provides native platform behavior.
/// Supports different alert types, actions, text fields, and custom styling.
class DCFAlert extends DCFStatelessComponent {
  /// Whether the alert is visible
  final bool visible;
  
  /// Title of the alert
  final String? title;
  
  /// Message content of the alert
  final String? message;
  
  /// Style of the alert
  final DCFAlertStyle style;
  
  /// List of text field configurations
  final List<DCFAlertTextField>? textFields;
  
  /// List of action configurations
  final List<DCFAlertAction>? actions;
  
  /// Whether the alert can be dismissed by tapping outside or back button
  final bool dismissible;
  
  /// Called when alert is shown
  final Function(Map<dynamic, dynamic>)? onShow;
  
  /// Called when alert is dismissed
  final Function(Map<dynamic, dynamic>)? onDismiss;
  
  /// Called when an action is pressed (includes textFieldValues if present)
  final Function(Map<dynamic, dynamic>)? onActionPress;
  
  /// Called when text field content changes
  final Function(Map<dynamic, dynamic>)? onTextFieldChange;
  
  
   DCFAlert({
    super.key,
    required this.visible,
    this.title,
    this.message,
    this.textFields,
    this.style = DCFAlertStyle.alert,
    this.actions,
    this.dismissible = true,
    this.onShow,
    this.onDismiss,
    this.onActionPress,
    this.onTextFieldChange,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = {};
    
    if (onShow != null) {
      eventMap['onShow'] = onShow;
    }
    
    if (onDismiss != null) {
      eventMap['onDismiss'] = onDismiss;
    }
    
    if (onActionPress != null) {
      eventMap['onActionPress'] = onActionPress;
    }
    
    if (onTextFieldChange != null) {
      eventMap['onTextFieldChange'] = onTextFieldChange;
    }

    Map<String, dynamic> props = {
      'visible': visible,
      'style': style.value,
      'dismissible': dismissible,
    };
    
    props.addAll(eventMap);

    Map<String, dynamic> alertContent = {
      'title': title,
      'message': message,
    };
    props['alertContent'] = alertContent;

    if (textFields != null && textFields!.isNotEmpty) {
      props['textFields'] = textFields!.map((textField) => textField.toMap()).toList();
    }

    if (actions != null && actions!.isNotEmpty) {
      props['actions'] = actions!.map((action) => action.toMap()).toList();
    }
    
    return DCFElement(
      type: 'Alert',
      elementProps: props,
      children: const [], // Alerts don't support children anymore - use textFields instead
    );
  }

  /// Helper method to create a simple alert with OK button
  static DCFAlert simple({
    required String title,
    required String message,
    Function(Map<dynamic, dynamic>)? onDismiss,
  }) {
    return DCFAlert(
      visible: true,
      title: title,
      message: message,
      actions: [
        DCFAlertAction(
          title: 'OK',
          style: DCFAlertActionStyle.defaultStyle,
          handler: 'dismiss',
        )
      ],
      onDismiss: onDismiss,
    );
  }

  /// Helper method to create a text input alert
  static DCFAlert textInput({
    required String title,
    String? message,
    required String placeholder,
    String? initialText,
    bool isSecure = false,
    DCFKeyboardType keyboardType = DCFKeyboardType.defaultType,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    Function(String text)? onConfirm,
    Function()? onCancel,
    Function(String text)? onTextChange,
  }) {
    return DCFAlert(
      visible: true,
      title: title,
      message: message,
      textFields: [
        DCFAlertTextField(
          placeholder: placeholder,
          text: initialText,
          secureTextEntry: isSecure,
          keyboardType: keyboardType,
        ),
      ],
      actions: [
        DCFAlertAction(
          title: cancelText,
          style: DCFAlertActionStyle.cancel,
          handler: 'cancel',
        ),
        DCFAlertAction(
          title: confirmText,
          style: DCFAlertActionStyle.defaultStyle,
          handler: 'confirm',
        ),
      ],
      onActionPress: (data) {
        if (data['handler'] == 'confirm' && onConfirm != null) {
          List<String> textValues = List<String>.from(data['textFieldValues'] ?? []);
          if (textValues.isNotEmpty) {
            onConfirm(textValues[0]);
          }
        } else if (data['handler'] == 'cancel' && onCancel != null) {
          onCancel();
        }
      },
      onTextFieldChange: onTextChange != null ? (data) {
        if (data['fieldIndex'] == 0) {
          onTextChange(data['text'] ?? '');
        }
      } : null,
    );
  }

  /// Helper method to create a login alert with username and password fields
  static DCFAlert login({
    String title = 'Login',
    String? message,
    String usernamePlaceholder = 'Username',
    String passwordPlaceholder = 'Password',
    String? initialUsername,
    DCFKeyboardType usernameKeyboardType = DCFKeyboardType.emailAddress,
    String loginText = 'Login',
    String cancelText = 'Cancel',
    Function(String username, String password)? onLogin,
    Function()? onCancel,
    Function(String username, String password)? onTextChange,
  }) {
    return DCFAlert(
      visible: true,
      title: title,
      message: message,
      textFields: [
        DCFAlertTextField(
          placeholder: usernamePlaceholder,
          text: initialUsername,
          keyboardType: usernameKeyboardType,
          autoCapitalization: DCFAutoCapitalizationType.none,
        ),
        DCFAlertTextField.secure(
          placeholder: passwordPlaceholder,
        ),
      ],
      actions: [
        DCFAlertAction(
          title: cancelText,
          style: DCFAlertActionStyle.cancel,
          handler: 'cancel',
        ),
        DCFAlertAction(
          title: loginText,
          style: DCFAlertActionStyle.defaultStyle,
          handler: 'login',
        ),
      ],
      onActionPress: (data) {
        if (data['handler'] == 'login' && onLogin != null) {
          List<String> textValues = List<String>.from(data['textFieldValues'] ?? []);
          if (textValues.length >= 2) {
            onLogin(textValues[0], textValues[1]);
          }
        } else if (data['handler'] == 'cancel' && onCancel != null) {
          onCancel();
        }
      },
      onTextFieldChange: onTextChange != null ? (data) {
        List<String> currentValues = ['', ''];  // username, password
        if (data['fieldIndex'] == 0) {
          currentValues[0] = data['text'] ?? '';
        } else if (data['fieldIndex'] == 1) {
          currentValues[1] = data['text'] ?? '';
        }
        onTextChange(currentValues[0], currentValues[1]);
      } : null,
    );
  }

  /// Helper method to create a confirmation alert with Yes/No buttons
  static DCFAlert confirmation({
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
    Function(Map<dynamic, dynamic>)? onConfirm,
    Function(Map<dynamic, dynamic>)? onCancel,
  }) {
    return DCFAlert(
      visible: true,
      title: title,
      message: message,
      actions: [
        DCFAlertAction(
          title: cancelText,
          style: DCFAlertActionStyle.cancel,
          handler: 'cancel',
        ),
        DCFAlertAction(
          title: confirmText,
          style: DCFAlertActionStyle.defaultStyle,
          handler: 'confirm',
        )
      ],
      onActionPress: (data) {
        if (data['handler'] == 'confirm' && onConfirm != null) {
          onConfirm(data);
        } else if (data['handler'] == 'cancel' && onCancel != null) {
          onCancel(data);
        }
      },
    );
  }

  /// Helper method to create a destructive action alert
  static DCFAlert destructive({
    required String title,
    required String message,
    String destructiveText = 'Delete',
    String cancelText = 'Cancel',
    Function(Map<dynamic, dynamic>)? onDestructive,
    Function(Map<dynamic, dynamic>)? onCancel,
  }) {
    return DCFAlert(
      visible: true,
      title: title,
      message: message,
      actions: [
        DCFAlertAction(
          title: cancelText,
          style: DCFAlertActionStyle.cancel,
          handler: 'cancel',
        ),
        DCFAlertAction(
          title: destructiveText,
          style: DCFAlertActionStyle.destructive,
          handler: 'destructive',
        )
      ],
      onActionPress: (data) {
        if (data['handler'] == 'destructive' && onDestructive != null) {
          onDestructive(data);
        } else if (data['handler'] == 'cancel' && onCancel != null) {
          onCancel(data);
        }
      },
    );
  }
}

