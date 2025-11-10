/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Text input focus callback data
class DCFTextInputFocusData {
  /// Whether the input is focused
  final bool isFocused;
  
  /// Timestamp of the focus change
  final DateTime timestamp;

  DCFTextInputFocusData({
    required this.isFocused,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTextInputFocusData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTextInputFocusData(
      isFocused: data['isFocused'] as bool,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Text input blur callback data
class DCFTextInputBlurData {
  /// Whether the input is blurred
  final bool isBlurred;
  
  /// Timestamp of the blur
  final DateTime timestamp;

  DCFTextInputBlurData({
    required this.isBlurred,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTextInputBlurData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTextInputBlurData(
      isBlurred: data['isBlurred'] as bool,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Text input submit callback data
class DCFTextInputSubmitData {
  /// The submitted text
  final String text;
  
  /// Timestamp of the submit
  final DateTime timestamp;

  DCFTextInputSubmitData({
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTextInputSubmitData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTextInputSubmitData(
      text: data['text'] as String,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Text input key press callback data
class DCFTextInputKeyPressData {
  /// The key that was pressed
  final String key;
  
  /// Timestamp of the key press
  final DateTime timestamp;

  DCFTextInputKeyPressData({
    required this.key,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTextInputKeyPressData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTextInputKeyPressData(
      key: data['key'] as String,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Text input selection change callback data
class DCFTextInputSelectionData {
  /// Start position of selection
  final int start;
  
  /// End position of selection
  final int end;
  
  /// Timestamp of the selection change
  final DateTime timestamp;

  DCFTextInputSelectionData({
    required this.start,
    required this.end,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTextInputSelectionData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTextInputSelectionData(
      start: data['start'] as int,
      end: data['end'] as int,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Text input end editing callback data
class DCFTextInputEndEditingData {
  /// The final text
  final String text;
  
  /// Timestamp of the end editing
  final DateTime timestamp;

  DCFTextInputEndEditingData({
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTextInputEndEditingData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTextInputEndEditingData(
      text: data['text'] as String,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// DCFTextInput - Cross-platform text input component
/// Provides native text input functionality with comprehensive type safety
class DCFTextInput extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
  final DCFLayout? layout;
  final DCFStyleSheet? styleSheet;
  final String? value;
  final String? defaultValue;
  final String? placeholder;
  /// Explicit color override: placeholderColor (overrides StyleSheet.secondaryColor)
  /// If provided, this will override the semantic secondaryColor for placeholder text
  final Color? placeholderColor;
  final DCFTextInputType inputType;
  final DCFKeyboardType keyboardType;
  final DCFAutoCapitalizationType autoCapitalization;
  final DCFReturnKeyType returnKeyType;
  final DCFTextContentType textContentType;
  final bool autoCorrect;
  final bool autoFocus;
  final bool blurOnSubmit;
  final bool caretHidden;
  final bool clearButtonMode;
  final bool clearTextOnFocus;
  final bool contextMenuHidden;
  final bool editable;
  final bool enablesReturnKeyAutomatically;
  final int? maxLength;
  final int? numberOfLines;
  final bool multiline;
  final bool secureTextEntry;
  final bool selectTextOnFocus;
  /// Explicit color override: selectionColor (overrides StyleSheet.accentColor)
  /// If provided, this will override the semantic accentColor for text selection
  final Color? selectionColor;
  final bool spellCheck;
  final String? textAlign;
  /// Explicit color override: textColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for text
  final Color? textColor;
  final double? fontSize;
  final String? fontWeight;
  final String? fontFamily;
  final void Function(String)? onChangeText;
  final Function(DCFTextInputFocusData)? onFocus;
  final Function(DCFTextInputBlurData)? onBlur;
  final Function(DCFTextInputSubmitData)? onSubmitEditing;
  final Function(DCFTextInputKeyPressData)? onKeyPress;
  final Function(DCFTextInputSelectionData)? onSelectionChange;
  final Function(DCFTextInputEndEditingData)? onEndEditing;

  DCFTextInput({
    super.key,
    this.styleSheet,
    this.layout = const DCFLayout(height: 50, width: 200),
    this.value,
    this.defaultValue,
    this.placeholder,
    this.placeholderColor,
    this.inputType = DCFTextInputType.text,
    this.keyboardType = DCFKeyboardType.defaultType,
    this.autoCapitalization = DCFAutoCapitalizationType.sentences,
    this.returnKeyType = DCFReturnKeyType.defaultReturn,
    this.textContentType = DCFTextContentType.none,
    this.autoCorrect = true,
    this.autoFocus = false,
    this.blurOnSubmit = true,
    this.caretHidden = false,
    this.clearButtonMode = false,
    this.clearTextOnFocus = false,
    this.contextMenuHidden = false,
    this.editable = true,
    this.enablesReturnKeyAutomatically = false,
    this.maxLength,
    this.numberOfLines = 1,
    this.multiline = false,
    this.secureTextEntry = false,
    this.selectTextOnFocus = false,
    this.selectionColor,
    this.spellCheck = true,
    this.textAlign,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.onChangeText,
    this.onFocus,
    this.onBlur,
    this.onSubmitEditing,
    this.onKeyPress,
    this.onSelectionChange,
    this.onEndEditing,
  });

  @override
  DCFComponentNode render() {
    final events = <String, dynamic>{};

   if (onChangeText != null) {
  events['onChangeText'] = (Map<dynamic, dynamic> data) {
    onChangeText!(data['text'] as String);
  };
}
    if (onFocus != null) {
      events['onFocus'] = (Map<dynamic, dynamic> data) {
        onFocus!(DCFTextInputFocusData.fromMap(data));
      };
    }
    if (onBlur != null) {
      events['onBlur'] = (Map<dynamic, dynamic> data) {
        onBlur!(DCFTextInputBlurData.fromMap(data));
      };
    }
    if (onSubmitEditing != null) {
      events['onSubmitEditing'] = (Map<dynamic, dynamic> data) {
        onSubmitEditing!(DCFTextInputSubmitData.fromMap(data));
      };
    }
    if (onKeyPress != null) {
      events['onKeyPress'] = (Map<dynamic, dynamic> data) {
        onKeyPress!(DCFTextInputKeyPressData.fromMap(data));
      };
    }
    if (onSelectionChange != null) {
      events['onSelectionChange'] = (Map<dynamic, dynamic> data) {
        onSelectionChange!(DCFTextInputSelectionData.fromMap(data));
      };
    }
    if (onEndEditing != null) {
      events['onEndEditing'] = (Map<dynamic, dynamic> data) {
        onEndEditing!(DCFTextInputEndEditingData.fromMap(data));
      };
    }

    return DCFElement(
      type: 'TextInput',
      key: key,
      elementProps: {
        'value': value,
        'defaultValue': defaultValue,
        'placeholder': placeholder,
        if (placeholderColor != null) 'placeholderColor': DCFColors.toNativeString(placeholderColor!),
        'inputType': inputType.name,
        'keyboardType': keyboardType.name,
        'autoCapitalization': autoCapitalization.name,
        'returnKeyType': returnKeyType.name,
        'textContentType': textContentType.name,
        'autoCorrect': autoCorrect,
        'autoFocus': autoFocus,
        'blurOnSubmit': blurOnSubmit,
        'caretHidden': caretHidden,
        'clearButtonMode': clearButtonMode,
        'clearTextOnFocus': clearTextOnFocus,
        'contextMenuHidden': contextMenuHidden,
        'editable': editable,
        'enablesReturnKeyAutomatically': enablesReturnKeyAutomatically,
        'maxLength': maxLength,
        'numberOfLines': numberOfLines,
        'multiline': multiline,
        'secureTextEntry': secureTextEntry,
        'selectTextOnFocus': selectTextOnFocus,
        if (selectionColor != null) 'selectionColor': DCFColors.toNativeString(selectionColor!),
        'spellCheck': spellCheck,
        'textAlign': textAlign,
        if (textColor != null) 'textColor': DCFColors.toNativeString(textColor!),
        'fontSize': fontSize,
        'fontWeight': fontWeight,
        'fontFamily': fontFamily,
        ...layout?.toMap() ?? {},
        ...styleSheet?.toMap() ?? {},
        ...events,
      },
      children: [],
    );
  }
}

/// Text input types
enum DCFTextInputType {
  text,
  email,
  password,
  number,
  phone,
  url,
  search,
  multiline,
}

/// Keyboard types
enum DCFKeyboardType {
  defaultType,
  asciiCapable,
  numbersAndPunctuation,
  numberPad,
  phonePad,
  namePhonePad,
  emailAddress,
  decimalPad,
  twitter,
  webSearch,
  asciiCapableNumberPad,
}

/// Auto-capitalization types
enum DCFAutoCapitalizationType {
  none,
  words,
  sentences,
  allCharacters,
}

/// Return key types
enum DCFReturnKeyType {
  defaultReturn,
  go,
  google,
  join,
  next,
  route,
  search,
  send,
  yahoo,
  done,
  emergencyCall,
  continue_,
}

/// Text content types for autofill
enum DCFTextContentType {
  none,
  addressCity,
  addressCityAndState,
  addressState,
  countryName,
  creditCardNumber,
  emailAddress,
  familyName,
  fullStreetAddress,
  givenName,
  jobTitle,
  location,
  middleName,
  name,
  namePrefix,
  nameSuffix,
  nickname,
  organizationName,
  postalCode,
  streetAddressLine1,
  streetAddressLine2,
  sublocality,
  telephoneNumber,
  url,
  username,
  password,
  newPassword,
  oneTimeCode,
}
