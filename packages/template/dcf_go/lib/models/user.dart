import 'dart:ui';

class User {
  final String id;
  final String name;
  final String initials;
  final Color avatarColor;
  final String lastMessage;
  final String time;

  User({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.lastMessage,
    required this.time,
  });
}
