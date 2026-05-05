import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';
import '../models/user.dart';
import '../components/message_bubble.dart';
import '../data/mock_data.dart';

/// Chat Detail - Shows conversation with a user
class ChatDetailView extends DCFStatefulComponent {
  final User user;
  final VoidCallback onBack;

  ChatDetailView({required this.user, required this.onBack, super.key});

  @override
  DCFComponentNode render() {
    final messages = mockMessages[user.id] ?? [];
    final inputValue = signal('');

    return DCFView(
      layout: DCFLayout(
        width: '100%',
        height: '100%',
        flexDirection: DCFFlexDirection.column,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: Color(0xFF000000),
      ),
      children: [
        // Header
        DCFView(
          layout: DCFLayout(
            width: '100%',
            paddingTop: 50, // Safe area for status bar
            paddingBottom: 8,
            paddingHorizontal: 16,
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 12,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Color(0xFF1C1C1E),
            borderBottomWidth: 0.5,
            borderBottomColor: Color(0xFF38383A),
          ),
          children: [
            // Back button
            DCFButton(
              layout: DCFLayout(width: 36, height: 36),
              styleSheet: DCFStyleSheet(
                backgroundColor: Color(0xFF2C2C2E),
                borderRadius: 18,
              ),
              onPress: (DCFButtonPressData data) => onBack(),
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
                      content: '←',
                      textColor: DCFColors.white,
                      textProps: DCFTextProps(fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),

            // User avatar
            DCFView(
              layout: DCFLayout(width: 36, height: 36),
              styleSheet: DCFStyleSheet(
                backgroundColor: user.avatarColor,
                borderRadius: 18,
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
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // User name
            DCFText(
              content: user.name,
              textColor: DCFColors.white,
              textProps: DCFTextProps(
                fontSize: 17,
                fontWeight: DCFFontWeight.semibold,
              ),
            ),
          ],
        ),

        // Messages
        DCFView(
          layout: DCFLayout(
            width: '100%',
            flexGrow: 1,
            flexDirection: DCFFlexDirection.column,
            padding: 16,
            gap: 8,
          ),
          children: messages.map((msg) {
            return MessageBubble(message: msg);
          }).toList(),
        ),

        // Input area
        DCFView(
          layout: DCFLayout(
            width: '100%',
            height: 64,
            paddingHorizontal: 16,
            paddingVertical: 8,
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 8,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Color(0xFF1C1C1E),
            borderTopWidth: 0.5,
            borderTopColor: Color(0xFF38383A),
          ),
          children: [
            // Text input wrapper
            DCFView(
              layout: DCFLayout(
                flexGrow: 1,
                height: 40,
                paddingHorizontal: 16,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: Color(0xFF2C2C2E),
                borderRadius: 20,
              ),
              children: [
                DCFTextInput(
                  layout: DCFLayout(width: '100%', height: 40),
                  placeholder: 'Message',
                  placeholderColor: Color(0xFF8E8E93),
                  fontSize: 16,
                  textColor: DCFColors.white,
                  onChangeText: (text) {
                    inputValue.set(text);
                  },
                ),
              ],
            ),

            // Send button
            DCFButton(
              layout: DCFLayout(width: 40, height: 40),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.blue,
                borderRadius: 20,
              ),
              onPress: (DCFButtonPressData data) {
                if (inputValue().isNotEmpty) {
                  inputValue.set('');
                }
              },
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
                      content: '→',
                      textColor: DCFColors.white,
                      textProps: DCFTextProps(
                        fontSize: 20,
                        fontWeight: DCFFontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
