/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:flutter/material.dart';

/// DCFColors - Comprehensive color system for DCFlight
/// 
/// Provides a large collection of beautiful colors with clear distinction
/// between black and transparent to avoid parsing issues on native platforms.
/// 
/// Usage:
/// ```dart
/// DCFStyleSheet(
///   primaryColor: DCFColors.blue,
///   backgroundColor: DCFColors.white,
/// )
/// ```
class DCFColors {
  DCFColors._();

  // ============================================================================
  // BASE COLORS - Clear distinction from transparent
  // ============================================================================
  
  /// Pure black - explicitly marked to distinguish from transparent
  static const Color black = Color(0xFF000000);
  
  /// Pure white
  static const Color white = Color(0xFFFFFFFF);
  
  /// Transparent - explicitly marked (alpha = 0)
  static const Color transparent = Color(0x00000000);
  
  /// Clear - alias for transparent
  static const Color clear = transparent;

  // ============================================================================
  // GRAYS - Material Design & iOS inspired
  // ============================================================================
  
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = Color(0xFF212121);
  
  // iOS Grays
  static const Color lightGray = Color(0xFFD3D3D3);
  static const Color darkGray = Color(0xFFA9A9A9);

  // ============================================================================
  // BLUES - Material Design & iOS inspired
  // ============================================================================
  
  static const Color blue50 = Color(0xFFE3F2FD);
  static const Color blue100 = Color(0xFFBBDEFB);
  static const Color blue200 = Color(0xFF90CAF9);
  static const Color blue300 = Color(0xFF64B5F6);
  static const Color blue400 = Color(0xFF42A5F5);
  static const Color blue500 = Color(0xFF2196F3); // Material Blue
  static const Color blue600 = Color(0xFF1E88E5);
  static const Color blue700 = Color(0xFF1976D2);
  static const Color blue800 = Color(0xFF1565C0);
  static const Color blue900 = Color(0xFF0D47A1);
  
  // iOS Blues
  static const Color blue = Color(0xFF007AFF); // iOS System Blue
  static const Color lightBlue = Color(0xFF5AC8FA);
  static const Color darkBlue = Color(0xFF0051D5);
  
  // Material Accent Blues
  static const Color blueAccent = Color(0xFF448AFF);
  static const Color lightBlueAccent = Color(0xFF40C4FF);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color indigoAccent = Color(0xFF536DFE);

  // ============================================================================
  // REDS - Material Design & iOS inspired
  // ============================================================================
  
  static const Color red50 = Color(0xFFEFEBE9);
  static const Color red100 = Color(0xFFFFCDD2);
  static const Color red200 = Color(0xFFEF9A9A);
  static const Color red300 = Color(0xFFE57373);
  static const Color red400 = Color(0xFFEF5350);
  static const Color red500 = Color(0xFFF44336); // Material Red
  static const Color red600 = Color(0xFFE53935);
  static const Color red700 = Color(0xFFD32F2F);
  static const Color red800 = Color(0xFFC62828);
  static const Color red900 = Color(0xFFB71C1C);
  
  // iOS Reds
  static const Color red = Color(0xFFFF3B30); // iOS System Red
  static const Color lightRed = Color(0xFFFF6961);
  static const Color darkRed = Color(0xFFCC0000);
  
  // Material Accent Reds
  static const Color redAccent = Color(0xFFFF5252);
  static const Color pink = Color(0xFFE91E63);
  static const Color pinkAccent = Color(0xFFFF4081);

  // ============================================================================
  // GREENS - Material Design & iOS inspired
  // ============================================================================
  
  static const Color green50 = Color(0xFFE8F5E9);
  static const Color green100 = Color(0xFFC8E6C9);
  static const Color green200 = Color(0xFFA5D6A7);
  static const Color green300 = Color(0xFF81C784);
  static const Color green400 = Color(0xFF66BB6A);
  static const Color green500 = Color(0xFF4CAF50); // Material Green
  static const Color green600 = Color(0xFF43A047);
  static const Color green700 = Color(0xFF388E3C);
  static const Color green800 = Color(0xFF2E7D32);
  static const Color green900 = Color(0xFF1B5E20);
  
  // iOS Greens
  static const Color green = Color(0xFF34C759); // iOS System Green
  static const Color lightGreen = Color(0xFF90EE90);
  static const Color darkGreen = Color(0xFF228B22);
  
  // Material Accent Greens
  static const Color greenAccent = Color(0xFF69F0AE);
  static const Color teal = Color(0xFF009688);
  static const Color tealAccent = Color(0xFF64FFDA);

  // ============================================================================
  // YELLOWS & ORANGES - Material Design & iOS inspired
  // ============================================================================
  
  static const Color yellow50 = Color(0xFFFFFDE7);
  static const Color yellow100 = Color(0xFFFFF9C4);
  static const Color yellow200 = Color(0xFFFFF59D);
  static const Color yellow300 = Color(0xFFFFF176);
  static const Color yellow400 = Color(0xFFFFEE58);
  static const Color yellow500 = Color(0xFFFFEB3B); // Material Yellow
  static const Color yellow600 = Color(0xFFFDD835);
  static const Color yellow700 = Color(0xFFFBC02D);
  static const Color yellow800 = Color(0xFFF9A825);
  static const Color yellow900 = Color(0xFFF57F17);
  
  // iOS Yellows
  static const Color yellow = Color(0xFFFFCC00); // iOS System Yellow
  static const Color lightYellow = Color(0xFFFFFF00);
  static const Color darkYellow = Color(0xFFCC9900);
  
  // Oranges
  static const Color orange50 = Color(0xFFFFF3E0);
  static const Color orange100 = Color(0xFFFFE0B2);
  static const Color orange200 = Color(0xFFFFCC80);
  static const Color orange300 = Color(0xFFFFB74D);
  static const Color orange400 = Color(0xFFFFA726);
  static const Color orange500 = Color(0xFFFF9800); // Material Orange
  static const Color orange600 = Color(0xFFFB8C00);
  static const Color orange700 = Color(0xFFF57C00);
  static const Color orange800 = Color(0xFFEF6C00);
  static const Color orange900 = Color(0xFFE65100);
  
  // iOS Oranges
  static const Color orange = Color(0xFFFF9500); // iOS System Orange
  static const Color lightOrange = Color(0xFFFFA500);
  static const Color darkOrange = Color(0xFFFF8C00);
  
  // Material Accent Oranges
  static const Color orangeAccent = Color(0xFFFFAB40);
  static const Color deepOrange = Color(0xFFFF5722);
  static const Color deepOrangeAccent = Color(0xFFFF6E40);
  static const Color amber = Color(0xFFFFC107);
  static const Color amberAccent = Color(0xFFFFD740);

  // ============================================================================
  // PURPLES & VIOLETS - Material Design & iOS inspired
  // ============================================================================
  
  static const Color purple50 = Color(0xFFF3E5F5);
  static const Color purple100 = Color(0xFFE1BEE7);
  static const Color purple200 = Color(0xFFCE93D8);
  static const Color purple300 = Color(0xFFBA68C8);
  static const Color purple400 = Color(0xFFAB47BC);
  static const Color purple500 = Color(0xFF9C27B0); // Material Purple
  static const Color purple600 = Color(0xFF8E24AA);
  static const Color purple700 = Color(0xFF7B1FA2);
  static const Color purple800 = Color(0xFF6A1B9A);
  static const Color purple900 = Color(0xFF4A148C);
  
  // iOS Purples
  static const Color purple = Color(0xFFAF52DE); // iOS System Purple
  static const Color lightPurple = Color(0xFFDA70D6);
  static const Color darkPurple = Color(0xFF8B008B);
  
  // Material Accent Purples
  static const Color purpleAccent = Color(0xFFE040FB);
  static const Color deepPurple = Color(0xFF673AB7);
  static const Color deepPurpleAccent = Color(0xFF7C4DFF);
  static const Color violet = Color(0xFF9C27B0);

  // ============================================================================
  // CYANS & TURQUOISE - Material Design inspired
  // ============================================================================
  
  static const Color cyan50 = Color(0xFFE0F7FA);
  static const Color cyan100 = Color(0xFFB2EBF2);
  static const Color cyan200 = Color(0xFF80DEEA);
  static const Color cyan300 = Color(0xFF4DD0E1);
  static const Color cyan400 = Color(0xFF26C6DA);
  static const Color cyan500 = Color(0xFF00BCD4); // Material Cyan
  static const Color cyan600 = Color(0xFF00ACC1);
  static const Color cyan700 = Color(0xFF0097A7);
  static const Color cyan800 = Color(0xFF00838F);
  static const Color cyan900 = Color(0xFF006064);
  
  static const Color cyan = Color(0xFF00BCD4);
  static const Color cyanAccent = Color(0xFF18FFFF);
  static const Color turquoise = Color(0xFF40E0D0);
  static const Color aqua = Color(0xFF00FFFF);

  // ============================================================================
  // BROWNS & TANS - Material Design inspired
  // ============================================================================
  
  static const Color brown50 = Color(0xFFEFEBE9);
  static const Color brown100 = Color(0xFFD7CCC8);
  static const Color brown200 = Color(0xFFBCAAA4);
  static const Color brown300 = Color(0xFFA1887F);
  static const Color brown400 = Color(0xFF8D6E63);
  static const Color brown500 = Color(0xFF795548); // Material Brown
  static const Color brown600 = Color(0xFF6D4C41);
  static const Color brown700 = Color(0xFF5D4037);
  static const Color brown800 = Color(0xFF4E342E);
  static const Color brown900 = Color(0xFF3E2723);
  
  static const Color brown = Color(0xFF795548);
  static const Color tan = Color(0xFFD2B48C);
  static const Color beige = Color(0xFFF5F5DC);

  // ============================================================================
  // SPECIAL COLORS - Common UI colors
  // ============================================================================
  
  // System Colors
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemIndigo = Color(0xFF5856D6);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemPink = Color(0xFFFF2D55);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemTeal = Color(0xFF5AC8FA);
  static const Color systemYellow = Color(0xFFFFCC00);
  
  // Material Primary Colors
  static const Color materialBlue = Color(0xFF2196F3);
  static const Color materialRed = Color(0xFFF44336);
  static const Color materialGreen = Color(0xFF4CAF50);
  static const Color materialYellow = Color(0xFFFFEB3B);
  static const Color materialOrange = Color(0xFFFF9800);
  static const Color materialPurple = Color(0xFF9C27B0);
  static const Color materialPink = Color(0xFFE91E63);
  static const Color materialTeal = Color(0xFF009688);
  static const Color materialIndigo = Color(0xFF3F51B5);
  
  // Common UI Colors
  static const Color success = green;
  static const Color error = red;
  static const Color warning = orange;
  static const Color info = blue;
  
  // Social Media Colors
  static const Color facebook = Color(0xFF1877F2);
  static const Color twitter = Color(0xFF1DA1F2);
  static const Color instagram = Color(0xFFE4405F);
  static const Color linkedin = Color(0xFF0077B5);
  static const Color youtube = Color(0xFFFF0000);
  static const Color github = Color(0xFF181717);
  static const Color google = Color(0xFF4285F4);
  
  // ============================================================================
  // UTILITY METHODS
  // ============================================================================
  
  /// Convert DCFColor to a string that native code can parse
  /// Uses "dcf:" prefix to distinguish from regular hex colors
  /// Format: "dcf:black", "dcf:blue", "dcf:transparent", etc.
  static String toNativeString(Color color) {
    // Check for transparent first
    if (color.alpha == 0) {
      return 'dcf:transparent';
    }
    
    // Check for black (explicit)
    if (color.value == 0xFF000000) {
      return 'dcf:black';
    }
    
    // For other colors, use hex with dcf prefix
    final alpha = (color.a * 255.0).round() & 0xff;
    if (alpha == 255) {
      final hexValue = color.toARGB32() & 0xFFFFFF;
      return 'dcf:#${hexValue.toRadixString(16).padLeft(6, '0')}';
    } else {
      final argbValue = color.toARGB32();
      return 'dcf:#${argbValue.toRadixString(16).padLeft(8, '0')}';
    }
  }
  
  /// Get color by name (case-insensitive)
  /// Returns null if color name not found
  static Color? fromName(String name) {
    final lowerName = name.toLowerCase().trim();
    
    switch (lowerName) {
      // Base
      case 'black': return black;
      case 'white': return white;
      case 'transparent': case 'clear': return transparent;
      
      // Grays
      case 'gray50': case 'grey50': return gray50;
      case 'gray100': case 'grey100': return gray100;
      case 'gray200': case 'grey200': return gray200;
      case 'gray300': case 'grey300': return gray300;
      case 'gray400': case 'grey400': return gray400;
      case 'gray500': case 'grey500': return gray500;
      case 'gray600': case 'grey600': return gray600;
      case 'gray700': case 'grey700': return gray700;
      case 'gray800': case 'grey800': return gray800;
      case 'gray900': case 'grey900': return gray900;
      case 'lightgray': case 'lightgrey': return lightGray;
      case 'darkgray': case 'darkgrey': return darkGray;
      
      // Blues
      case 'blue': return blue;
      case 'blue50': return blue50;
      case 'blue100': return blue100;
      case 'blue200': return blue200;
      case 'blue300': return blue300;
      case 'blue400': return blue400;
      case 'blue500': return blue500;
      case 'blue600': return blue600;
      case 'blue700': return blue700;
      case 'blue800': return blue800;
      case 'blue900': return blue900;
      case 'lightblue': return lightBlue;
      case 'darkblue': return darkBlue;
      case 'blueaccent': return blueAccent;
      case 'indigo': return indigo;
      case 'indigoaccent': return indigoAccent;
      
      // Reds
      case 'red': return red;
      case 'red50': return red50;
      case 'red100': return red100;
      case 'red200': return red200;
      case 'red300': return red300;
      case 'red400': return red400;
      case 'red500': return red500;
      case 'red600': return red600;
      case 'red700': return red700;
      case 'red800': return red800;
      case 'red900': return red900;
      case 'lightred': return lightRed;
      case 'darkred': return darkRed;
      case 'redaccent': return redAccent;
      case 'pink': return pink;
      case 'pinkaccent': return pinkAccent;
      
      // Greens
      case 'green': return green;
      case 'green50': return green50;
      case 'green100': return green100;
      case 'green200': return green200;
      case 'green300': return green300;
      case 'green400': return green400;
      case 'green500': return green500;
      case 'green600': return green600;
      case 'green700': return green700;
      case 'green800': return green800;
      case 'green900': return green900;
      case 'lightgreen': return lightGreen;
      case 'darkgreen': return darkGreen;
      case 'greenaccent': return greenAccent;
      case 'teal': return teal;
      case 'tealaccent': return tealAccent;
      
      // Yellows & Oranges
      case 'yellow': return yellow;
      case 'yellow50': return yellow50;
      case 'yellow100': return yellow100;
      case 'yellow200': return yellow200;
      case 'yellow300': return yellow300;
      case 'yellow400': return yellow400;
      case 'yellow500': return yellow500;
      case 'yellow600': return yellow600;
      case 'yellow700': return yellow700;
      case 'yellow800': return yellow800;
      case 'yellow900': return yellow900;
      case 'lightyellow': return lightYellow;
      case 'darkyellow': return darkYellow;
      case 'orange': return orange;
      case 'orange50': return orange50;
      case 'orange100': return orange100;
      case 'orange200': return orange200;
      case 'orange300': return orange300;
      case 'orange400': return orange400;
      case 'orange500': return orange500;
      case 'orange600': return orange600;
      case 'orange700': return orange700;
      case 'orange800': return orange800;
      case 'orange900': return orange900;
      case 'lightorange': return lightOrange;
      case 'darkorange': return darkOrange;
      case 'orangeaccent': return orangeAccent;
      case 'deeporange': return deepOrange;
      case 'deeporangeaccent': return deepOrangeAccent;
      case 'amber': return amber;
      case 'amberaccent': return amberAccent;
      
      // Purples
      case 'purple': return purple;
      case 'purple50': return purple50;
      case 'purple100': return purple100;
      case 'purple200': return purple200;
      case 'purple300': return purple300;
      case 'purple400': return purple400;
      case 'purple500': return purple500;
      case 'purple600': return purple600;
      case 'purple700': return purple700;
      case 'purple800': return purple800;
      case 'purple900': return purple900;
      case 'lightpurple': return lightPurple;
      case 'darkpurple': return darkPurple;
      case 'purpleaccent': return purpleAccent;
      case 'deeppurple': return deepPurple;
      case 'deeppurpleaccent': return deepPurpleAccent;
      case 'violet': return violet;
      
      // Cyans
      case 'cyan': return cyan;
      case 'cyan50': return cyan50;
      case 'cyan100': return cyan100;
      case 'cyan200': return cyan200;
      case 'cyan300': return cyan300;
      case 'cyan400': return cyan400;
      case 'cyan500': return cyan500;
      case 'cyan600': return cyan600;
      case 'cyan700': return cyan700;
      case 'cyan800': return cyan800;
      case 'cyan900': return cyan900;
      case 'cyanaccent': return cyanAccent;
      case 'turquoise': return turquoise;
      case 'aqua': return aqua;
      
      // Browns
      case 'brown': return brown;
      case 'brown50': return brown50;
      case 'brown100': return brown100;
      case 'brown200': return brown200;
      case 'brown300': return brown300;
      case 'brown400': return brown400;
      case 'brown500': return brown500;
      case 'brown600': return brown600;
      case 'brown700': return brown700;
      case 'brown800': return brown800;
      case 'brown900': return brown900;
      case 'tan': return tan;
      case 'beige': return beige;
      
      // System Colors
      case 'systemblue': return systemBlue;
      case 'systemgreen': return systemGreen;
      case 'systemindigo': return systemIndigo;
      case 'systemorange': return systemOrange;
      case 'systempink': return systemPink;
      case 'systempurple': return systemPurple;
      case 'systemred': return systemRed;
      case 'systemteal': return systemTeal;
      case 'systemyellow': return systemYellow;
      
      // Material Colors
      case 'materialblue': return materialBlue;
      case 'materialred': return materialRed;
      case 'materialgreen': return materialGreen;
      case 'materialyellow': return materialYellow;
      case 'materialorange': return materialOrange;
      case 'materialpurple': return materialPurple;
      case 'materialpink': return materialPink;
      case 'materialteal': return materialTeal;
      case 'materialindigo': return materialIndigo;
      
      // Common UI
      case 'success': return success;
      case 'error': return error;
      case 'warning': return warning;
      case 'info': return info;
      
      // Social Media
      case 'facebook': return facebook;
      case 'twitter': return twitter;
      case 'instagram': return instagram;
      case 'linkedin': return linkedin;
      case 'youtube': return youtube;
      case 'github': return github;
      case 'google': return google;
      
      default: return null;
    }
  }
}

