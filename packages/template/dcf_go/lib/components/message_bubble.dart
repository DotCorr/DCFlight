import 'package:dcflight/dcflight.dart';
import '../models/message.dart';

/// Message bubble component
class MessageBubble extends DCFStatelessComponent {
  final Message message;

  MessageBubble({required this.message, super.key});

  @override
  DCFComponentNode render() {
    final isFromMe = message.isFromMe;

    return DCFView(
      layout: DCFLayout(
        width: '100%',
        flexDirection: DCFFlexDirection.row,
        justifyContent: isFromMe 
            ? DCFJustifyContent.flexEnd 
            : DCFJustifyContent.flexStart,
      ),
      children: [
        DCFView(
          layout: DCFLayout(
            maxWidth: '70%',
            paddingHorizontal: 14,
            paddingVertical: 10,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: isFromMe ? DCFColors.blue : Color(0xFF2C2C2E),
            borderRadius: 18,
          ),
          children: [
            DCFText(
              content: message.text,
              textColor: DCFColors.white,
              textProps: DCFTextProps(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
