/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
/// These declarations are compiler input. They are never linked into native apps.
class App {
  final int version;
  final String id, name;
  final Map<String, Object> state;
  final List<Action> actions;
  final Node root;
  const App({required this.version, required this.id, required this.name,
    this.state = const {}, this.actions = const [], required this.root});
}

class Node {
  final String id, type;
  final Map<String, Object> props;
  final List<Node> children;
  final String? action;
  const Node({required this.id, required this.type, required this.props,
    this.children = const [], this.action});
}

class Ref {
  final String name;
  const Ref({required this.name});
}

class Action {
  final String id, op;
  final String? target;
  final Object? value;
  const Action({required this.id, required this.op, this.target, this.value});
}
