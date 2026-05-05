class Message {
  final String text;
  final bool isFromMe;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isFromMe,
    required this.timestamp,
  });
}
