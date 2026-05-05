import 'package:dcflight/dcflight.dart';
import '../models/user.dart';

/// Individual chat item in the list
class ChatListItem extends DCFStatelessComponent {
  final User user;
  final VoidCallback onTap;

  ChatListItem({required this.user, required this.onTap, super.key});

  @override
  DCFComponentNode render() {
    return DCFButton(
      layout: DCFLayout(
        width: '100%',
        height: 76,
        paddingHorizontal: 16,
        paddingVertical: 12,
        flexDirection: DCFFlexDirection.row,
        alignItems: DCFAlign.center,
        gap: 12,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: Color(0xFF1C1C1E),
        borderBottomWidth: 0.5,
        borderBottomColor: Color(0xFF38383A),
      ),
      onPress: (DCFButtonPressData data) => onTap(),
      children: [
        // Avatar
        DCFView(
          layout: DCFLayout(width: 52, height: 52),
          styleSheet: DCFStyleSheet(
            backgroundColor: user.avatarColor,
            borderRadius: 26,
          ),
          children: [
            DCFView(
              layout: DCFLayout(
                width: '100%',
                height: '100%',
                justifyContent: DCFJustifyContent.center,
                alignItems: DCFAlign.center,
              ),
              children: [
                DCFText(
                  content: user.initials,
                  textColor: DCFColors.white,
                  textProps: DCFTextProps(
                    fontSize: 22,
                    fontWeight: DCFFontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Name and message preview
        DCFView(
          layout: DCFLayout(
            flexGrow: 1,
            flexDirection: DCFFlexDirection.column,
            gap: 4,
          ),
          children: [
            DCFText(
              content: user.name,
              textColor: DCFColors.white,
              textProps: DCFTextProps(
                fontSize: 17,
                fontWeight: DCFFontWeight.semibold,
              ),
            ),
            DCFText(
              content: user.lastMessage,
              textColor: Color(0xFF8E8E93),
              textProps: DCFTextProps(
                fontSize: 15,
              ),
            ),
          ],
        ),

        // Time and chevron
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.column,
            alignItems: DCFAlign.flexEnd,
            gap: 4,
          ),
          children: [
            DCFText(
              content: user.time,
              textColor: Color(0xFF8E8E93),
              textProps: DCFTextProps(
                fontSize: 14,
              ),
            ),
            DCFText(
              content: '›',
              textColor: Color(0xFF8E8E93),
              textProps: DCFTextProps(fontSize: 20),
            ),
          ],
        ),
      ],
    );
  }
}
