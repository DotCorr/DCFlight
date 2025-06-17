/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

class PortalTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final showPortal = useState<bool>(false, 'showPortal');

    return DCFScrollView(
      layout: LayoutProps(flex: 1, padding: 16),
      children: [
        DCFButton(buttonProps: DCFButtonProps(
          title: showPortal.state ? "Hide Portal" : "Show Portal",
        ),
        onPress: (v) {
          showPortal.setState(!showPortal.state);
        }),
        if(showPortal.state)
          DCFPortal(
            targetId: "test",
            children: [
              DCFText(
                content: "🎉 PORTAL CONTENT WORKS!",
                textProps: DCFTextProps(
                  fontSize: 18,
                  fontWeight: "bold",
                  color: Colors.green,
                ),
                layout: LayoutProps(marginBottom: 10),
              ),
            ],
          ),
        DCFPortalTarget(targetId: "test"),
        // This is the target where the portal will render its content
        DCFPortal(
          targetId: "test",
          children: [
            DCFText(
              content: "|-----------------PORTAL CONTENT-----------------|",
              textProps: DCFTextProps(
                fontSize: 18,
                fontWeight: "bold",
                color: Colors.green,
              ),
              layout: LayoutProps(marginBottom: 10),
            ),
          ],
        ),
      ],
    );
  }
}
