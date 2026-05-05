import 'package:dcflight/dcflight.dart';
import '../models/user.dart';
import '../components/chat_list_item.dart';
import '../data/mock_data.dart';

/// Chat List - Shows all conversations with stories
class ChatListView extends DCFStatelessComponent {
  final void Function(User) onUserTap;

  ChatListView({required this.onUserTap, super.key});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        height: '100%',
        flexDirection: DCFFlexDirection.column,
        alignItems: DCFAlign.stretch, // Stretch to fill width, not center
        justifyContent: DCFJustifyContent.flexStart, // Start from top
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: Color(0xFF000000),
      ),
      children: [
        // Header (fixed at top with safe area)
        DCFView(
          layout: DCFLayout(
            width: '100%',
            paddingTop: 50, // Safe area for status bar
            paddingBottom: 8,
            paddingHorizontal: 16,
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            justifyContent: DCFJustifyContent.spaceBetween,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Color(0xFF1C1C1E),
          ),
          children: [
            DCFText(
              content: 'Messages',
              textColor: DCFColors.white,
              textProps: DCFTextProps(
                fontSize: 34,
                fontWeight: DCFFontWeight.bold,
              ),
            ),
            // Compose button
            DCFView(
              layout: DCFLayout(width: 36, height: 36),
              styleSheet: DCFStyleSheet(
                borderRadius: 18,
                backgroundColor: DCFColors.blue,
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
                      content: '+',
                      textColor: DCFColors.white,
                      textProps: DCFTextProps(fontSize: 24, fontWeight: DCFFontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Stories Section (horizontal scroll)
        DCFView(
          layout: DCFLayout(
            width: '100%',
            height: 110,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Color(0xFF1C1C1E),
            borderBottomWidth: 0.5,
            borderBottomColor: Color(0xFF38383A),
          ),
          children: [
            DCFScrollView(
              horizontal: true,
              showsScrollIndicator: false,
              layout: DCFLayout(
                width: '100%',
                height: 110,
              ),
              scrollContent: [
                DCFView(
                  layout: DCFLayout(
                    flexDirection: DCFFlexDirection.row,
                    gap: 16,
                    paddingHorizontal: 12,
                    paddingVertical: 8,
                  ),
                  children: [
                    // My Story (add story)
                    DCFView(
                      layout: DCFLayout(
                        width: 68,
                        flexDirection: DCFFlexDirection.column,
                        alignItems: DCFAlign.center,
                        gap: 6,
                      ),
                      children: [
                        // Avatar with + indicator
                        DCFView(
                          layout: DCFLayout(width: 64, height: 64),
                          styleSheet: DCFStyleSheet(
                            backgroundColor: Color(0xFF2C2C2E),
                            borderRadius: 32,
                            borderWidth: 2,
                            borderColor: Color(0xFF3A3A3C),
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
                                  content: '+',
                                  textColor: DCFColors.white,
                                  textProps: DCFTextProps(fontSize: 28, fontWeight: DCFFontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        DCFText(
                          content: 'My Story',
                          textColor: Color(0xFF8E8E93),
                          textProps: DCFTextProps(fontSize: 12),
                        ),
                      ],
                    ),

                    // User stories
                    ...mockUsers.take(10).map((user) {
                      return DCFView(
                        layout: DCFLayout(
                          width: 68,
                          flexDirection: DCFFlexDirection.column,
                          alignItems: DCFAlign.center,
                          gap: 6,
                        ),
                        children: [
                          // Story avatar with gradient border
                          DCFView(
                            layout: DCFLayout(width: 68, height: 68),
                            styleSheet: DCFStyleSheet(
                              borderRadius: 34,
                              borderWidth: 3,
                              borderColor: DCFColors.blue, // Story indicator
                            ),
                            children: [
                              DCFView(
                                layout: DCFLayout(
                                  width: '100%',
                                  height: '100%',
                                  padding: 3,
                                ),
                                children: [
                                  DCFView(
                                    layout: DCFLayout(width: '100%', height: '100%'),
                                    styleSheet: DCFStyleSheet(
                                      backgroundColor: user.avatarColor,
                                      borderRadius: 28,
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
                          ),
                          DCFText(
                            content: user.name.split(' ')[0], // First name only
                            textColor: DCFColors.white,
                            textProps: DCFTextProps(fontSize: 12),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Chats label
        DCFView(
          layout: DCFLayout(
            width: '100%',
            paddingHorizontal: 16,
            paddingVertical: 8,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: Color(0xFF000000),
          ),
          children: [
            DCFText(
              content: 'CHATS',
              textColor: Color(0xFF8E8E93),
              textProps: DCFTextProps(
                fontSize: 13,
                fontWeight: DCFFontWeight.semibold,
              ),
            ),
          ],
        ),

        // Chat List (fills remaining space)
        DCFView(
          layout: DCFLayout(
            width: '100%',
            flexGrow: 1,
            flexDirection: DCFFlexDirection.column,
            alignItems: DCFAlign.stretch, // Stretch items to fill width
            justifyContent: DCFJustifyContent.flexStart, // Start from top
          ),
          children: mockUsers.map((user) {
            return ChatListItem(
              user: user,
              onTap: () => onUserTap(user),
            );
          }).toList(),
        ),
      ],
    );
  }
}
