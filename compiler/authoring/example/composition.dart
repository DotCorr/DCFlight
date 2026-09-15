/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
import 'package:dcflight_authoring/dcflight.dart';

Node friend(String id, String name) => Row(
  id: 'friend_$id',
  style: const Style(gap: 12, padding: 12, align: 'center'),
  children: [
    Icon('person', id: 'avatar_$id'),
    Text(
      name,
      id: 'name_$id',
      style: const Style(fontWeight: 'semibold'),
    ),
  ],
);

App buildApp() {
  final names = ['Ada', 'Lin', 'Sam'];
  return App(
    id: 'com.example.friends',
    name: 'Friends',
    state: {'search': '', 'notifications': true, 'progress': 60},
    actions: const [Action.toggle(id: 'mute', target: 'notifications')],
    root: Scroll(
      id: 'feed',
      children: [
        Column(
          id: 'content',
          style: const Style(padding: 24, gap: 16),
          children: [
            Text(
              'Friends',
              id: 'heading',
              style: const Style(fontSize: 28, fontWeight: 'bold'),
            ),
            TextField(
              id: 'search',
              value: const Ref<String>(name: 'search'),
              placeholder: 'Find a friend',
            ),
            Card(
              id: 'friends',
              children: [
                Column(
                  id: 'friendsList',
                  children: [
                    for (var i = 0; i < names.length; i++)
                      friend('$i', names[i]),
                  ],
                ),
              ],
            ),
            Toggle(
              'Notifications',
              id: 'notifications',
              value: const Ref<bool>(name: 'notifications'),
            ),
            ProgressBar.bind(const Ref<int>(name: 'progress'), id: 'progress'),
            Button(
              'Toggle notifications',
              id: 'mute',
              action: 'mute',
              motion: const Motion(),
            ),
          ],
        ),
      ],
    ),
  );
}
