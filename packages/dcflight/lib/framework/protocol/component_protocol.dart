/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



import '../renderer/vdom/component/component_node.dart';
import '../renderer/vdom/component/dcf_element.dart';

/// This will be used to register component factories with the framework
typedef ComponentFactory = DCFElement Function(Map<String, dynamic> props, List<DCFComponentNode> children);
