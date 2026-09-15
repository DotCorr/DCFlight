/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
import 'package:dcflight_authoring/dcflight.dart';
const app = App(
  version: 1, id: 'com.dotcorr.counter', name: 'Counter',
  state: {'count': 0, 'enabled': true, 'name': 'Ada'},
  actions: [Action(id: 'add', op: 'increment', target: 'count'), Action(id: 'reset', op: 'set', target: 'count', value: 0)],
  root: Node(id: 'home', type: 'column', props: {}, children: [
    Node(id: 'heading', type: 'text', props: {'text': 'Native Counter'}),
    Node(id: 'count', type: 'counter', props: {'value': Ref(name: 'count')}),
    Node(id: 'add', type: 'button', props: {'text': 'Add one'}, action: 'add'),
    Node(id: 'reset', type: 'button', props: {'text': 'Reset'}, action: 'reset'),
    Node(id: 'enabled', type: 'toggle', props: {'text': 'Enabled', 'value': Ref(name: 'enabled')}),
    Node(id: 'name', type: 'textField', props: {'value': Ref(name: 'name'), 'placeholder': 'Name'}),
    Node(id: 'greeting', type: 'text', props: {'text': Ref(name: 'name')})
  ]),
);
