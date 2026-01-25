/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
///
/// DCLogo (Dotcorr Logo) Component
///
/// ⚠️ TRADEMARK NOTICE ⚠️
///
/// This logo design is protected and registered as a trademark (© 2026 Dotcorr).
/// Dotcorr is a research company based in the Netherlands.
///
/// This logo may NOT be used for any commercial purposes under any circumstances.
/// Unauthorized use, reproduction, or distribution for commercial gain is strictly prohibited.
/// For inquiries, please contact Dotcorr.
///


import 'package:dcflight/dcflight.dart';

class DCLogo extends DCFStatelessComponent {
  final double size ;

  DCLogo({super.key, required this.size});
  @override
  DCFComponentNode render() {
  
    return DCFView(
      layout: DCFLayout(
        width: size,
        height: size,
        alignItems: DCFAlign.center,
        justifyContent: DCFJustifyContent.center,
      ),
     
      children: [
        // Base (Black background)
        DCFView(
          layout: DCFLayout(
            width: size,
            height: size,
            position: DCFPositionType.absolute,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.black,
            borderWidth: 1,
            borderColor: DCFColors.gray900,
          ),
        ),

        // Tower (White square rising up with 3D translateZ)
        DCFView(
          layout: DCFLayout(
            width: size * 0.35,
            height: size * 0.35,
            position: DCFPositionType.absolute,
            absoluteLayout: AbsoluteLayout(top: size * 0.15, left: size * 0.15),
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.white,
            shadowColor: DCFColors.white,
            shadowRadius: 20,
            shadowOpacity: 0.4,
          ),
          children: [],
        ),
      ],
    );
  }
}