/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

class ReallyLongList extends StatefulComponent{
  @override
  DCFComponentNode render() {
    return DCFFlatList(  onScroll: (v) {
        print("Scrolled to: v");
      },data: List<int>.generate(100, (i) => i + 1), renderItem: (v, i) {
      return DCFView(
        layout: LayoutProps(
          gap: 5,
          flexDirection: YogaFlexDirection.row,
          flexWrap: YogaWrap.wrap,
          height: 50,
          width: double.infinity,
          padding: 10,
          justifyContent: YogaJustifyContent.center,
        ),
        children: [
          DCFText(
            content: "Item $i",
            textProps: DCFTextProps(fontSize: 16, color: Colors.black),
          ),
        ],
      );
    });
  }
  
}