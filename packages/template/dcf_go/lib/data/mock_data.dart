import 'package:dcflight/dcflight.dart';
import '../models/user.dart';
import '../models/message.dart';

final mockUsers = [
  User(
    id: '1',
    name: 'Alice Johnson',
    initials: 'AJ',
    avatarColor: DCFColors.blue,
    lastMessage: 'Hey! How are you doing?',
    time: '2m',
  ),
  User(
    id: '2',
    name: 'Bob Smith',
    initials: 'BS',
    avatarColor: DCFColors.green,
    lastMessage: 'Can we meet tomorrow?',
    time: '15m',
  ),
  User(
    id: '3',
    name: 'Charlie Brown',
    initials: 'CB',
    avatarColor: DCFColors.orange,
    lastMessage: 'Thanks for your help!',
    time: '1h',
  ),
  User(
    id: '4',
    name: 'Diana Prince',
    initials: 'DP',
    avatarColor: DCFColors.purple,
    lastMessage: 'See you later!',
    time: '2h',
  ),
  User(
    id: '5',
    name: 'Ethan Hunt',
    initials: 'EH',
    avatarColor: DCFColors.red,
    lastMessage: 'Mission accomplished 🎯',
    time: '3h',
  ),
];

final mockMessages = {
  '1': [
    Message(
      text: 'Hey! How are you doing?',
      isFromMe: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
    ),
    Message(
      text: 'I\'m good! How about you?',
      isFromMe: true,
      timestamp: DateTime.now().subtract(Duration(minutes: 4)),
    ),
    Message(
      text: 'Pretty great! Just finished a big project',
      isFromMe: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 3)),
    ),
    Message(
      text: 'That\'s awesome! Congrats! 🎉',
      isFromMe: true,
      timestamp: DateTime.now().subtract(Duration(minutes: 2)),
    ),
  ],
  '2': [
    Message(
      text: 'Can we meet tomorrow?',
      isFromMe: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 15)),
    ),
    Message(
      text: 'Sure! What time works for you?',
      isFromMe: true,
      timestamp: DateTime.now().subtract(Duration(minutes: 14)),
    ),
    Message(
      text: 'How about 3 PM at the coffee shop?',
      isFromMe: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 13)),
    ),
  ],
  '3': [
    Message(
      text: 'Thanks for your help!',
      isFromMe: false,
      timestamp: DateTime.now().subtract(Duration(hours: 1)),
    ),
  ],
  '4': [
    Message(
      text: 'See you later!',
      isFromMe: false,
      timestamp: DateTime.now().subtract(Duration(hours: 2)),
    ),
    Message(
      text: 'Take care!',
      isFromMe: true,
      timestamp: DateTime.now().subtract(Duration(hours: 2)),
    ),
  ],
  '5': [
    Message(
      text: 'Mission accomplished 🎯',
      isFromMe: false,
      timestamp: DateTime.now().subtract(Duration(hours: 3)),
    ),
    Message(
      text: 'Well done! You\'re the best!',
      isFromMe: true,
      timestamp: DateTime.now().subtract(Duration(hours: 3)),
    ),
  ],
};
