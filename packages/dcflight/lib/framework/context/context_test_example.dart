/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Simple theme class for context example
class AppTheme {
  final String name;
  final String backgroundColor;
  final String textColor;
  final String accentColor;
  
  AppTheme({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
  });
  
  static final light = AppTheme(
    name: 'Light Theme',
    backgroundColor: '#FFFFFF',
    textColor: '#000000',
    accentColor: '#007AFF',
  );
  
  static final dark = AppTheme(
    name: 'Dark Theme',
    backgroundColor: '#000000',
    textColor: '#FFFFFF',
    accentColor: '#0A84FF',
  );
}

/// Create the theme context
final ThemeContext = createContext<AppTheme>(defaultValue: AppTheme.light);

/// Test app component that demonstrates Context API
class ContextTestApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    // Provide dark theme at the root level
    return DCFContextProvider(
      context: ThemeContext,
      value: AppTheme.dark,
      child: DCFView(
        layout: DCFLayout(
          flex: 1,
          padding: 20,
          justifyContent: YogaJustifyContent.center,
          alignItems: YogaAlign.center,
        ),
        children: [
          HeaderComponent(),
          ContentComponent(),
          FooterComponent(),
        ],
      ),
    );
  }
}

/// Header component that uses context
class HeaderComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useContext(ThemeContext);
    
    return DCFView(
      layout: DCFLayout(
        paddingBottom: 20,
        alignItems: YogaAlign.center,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.fromHex(theme.backgroundColor),
      ),
      children: [
        DCFText(
          text: '🎨 Context API Test',
          styleSheet: DCFStyleSheet(
            color: DCFColors.fromHex(theme.accentColor),
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
        ),
        DCFText(
          text: 'Current Theme: ${theme.name}',
          styleSheet: DCFStyleSheet(
            color: DCFColors.fromHex(theme.textColor),
            fontSize: 16,
            marginTop: 8,
          ),
        ),
      ],
    );
  }
}

/// Content component that uses context (nested deeper)
class ContentComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useContext(ThemeContext);
    
    return DCFView(
      layout: DCFLayout(
        padding: 16,
        marginTop: 20,
        marginBottom: 20,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.fromHex(theme.accentColor),
        borderRadius: 12,
      ),
      children: [
        DCFText(
          text: 'This component is nested deep in the tree',
          styleSheet: DCFStyleSheet(
            color: DCFColors.white,
            fontSize: 14,
            marginBottom: 8,
          ),
        ),
        DCFText(
          text: 'But it can access the theme context without prop drilling! ✨',
          styleSheet: DCFStyleSheet(
            color: DCFColors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Footer component that uses context
class FooterComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useContext(ThemeContext);
    
    return DCFView(
      layout: DCFLayout(
        paddingTop: 20,
        alignItems: YogaAlign.center,
      ),
      children: [
        DCFText(
          text: 'Background: ${theme.backgroundColor}',
          styleSheet: DCFStyleSheet(
            color: DCFColors.fromHex(theme.textColor),
            fontSize: 12,
          ),
        ),
        DCFText(
          text: 'Text: ${theme.textColor}',
          styleSheet: DCFStyleSheet(
            color: DCFColors.fromHex(theme.textColor),
            fontSize: 12,
            marginTop: 4,
          ),
        ),
        DCFText(
          text: 'Accent: ${theme.accentColor}',
          styleSheet: DCFStyleSheet(
            color: DCFColors.fromHex(theme.accentColor),
            fontSize: 12,
            marginTop: 4,
          ),
        ),
      ],
    );
  }
}








