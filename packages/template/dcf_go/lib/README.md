# Telegram-Style Messaging App

A clean messaging interface built with DCFlight's pure signals architecture.

## ✅ Fixed Issues

This app now uses **DCFlight's actual APIs**, NOT Flutter:

### Correct Padding/Margin Usage
```dart
// ✅ CORRECT - DCFlight uses numbers
DCFLayout(
  paddingHorizontal: 16,  // double/int
  paddingVertical: 8,     // double/int
  padding: 20,            // or all sides
)

// ❌ WRONG - Don't use Flutter's EdgeInsets
DCFLayout(
  padding: EdgeInsets.symmetric(...) // NO!
)
```

### Correct Event Handlers
```dart
// ✅ CORRECT - Type-safe callbacks
DCFButton(
  onPress: (DCFButtonPressData data) {
    // data.fromUser, data.timestamp
  },
)

DCFTextInput(
  onChangeText: (String text) {
    // Direct string, not map['text']
  },
)

// ❌ WRONG - Don't use dynamic maps
onPress: (_) => ... // loses type info
onChangeText: (data) => data['text'] // NO!
```

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry + navigation
├── models/                      # Data models
│   ├── user.dart               # User model
│   └── message.dart            # Message model
├── views/                       # Screen-level components
│   ├── chat_list_view.dart    # Main chat list
│   └── chat_detail_view.dart  # Individual chat
├── components/                  # Reusable UI
│   ├── chat_list_item.dart    # Chat preview item
│   └── message_bubble.dart    # Message bubble
└── data/                        # Mock data
    └── mock_data.dart          # Sample data
```

## ✨ Features

### Pure Signals Architecture
- **Zero component re-renders** for text input
- Direct native view updates via signals
- Smooth 60fps animations with reanimated

### Navigation
- Push/pop with slide animations
- Type-safe callbacks with `DCFButtonPressData`
- Reanimated-powered transitions

### UI
- Dark theme matching iOS/Telegram style
- Proper chat list with avatars
- Message bubbles (sent/received)
- Real-time text input

## 🎯 DCFlight API Patterns

### Layout
```dart
DCFLayout(
  width: '100%',          // String (percentage) or number
  height: 56,             // Number (pixels)
  paddingHorizontal: 16,  // Number
  gap: 12,                // Number
  flexDirection: DCFFlexDirection.row,
  alignItems: DCFAlign.center,
  justifyContent: DCFJustifyContent.spaceBetween,
)
```

### Styling
```dart
DCFStyleSheet(
  backgroundColor: Color(0xFF1C1C1E),  // dart:ui Color
  borderRadius: 18,                     // Number
  borderBottomWidth: 0.5,               // Number
  borderBottomColor: Color(0xFF38383A),
)
```

### Text
```dart
DCFText(
  content: 'Hello',
  textColor: DCFColors.white,  // Direct on DCFText
  textProps: DCFTextProps(     // Font props only
    fontSize: 17,
    fontWeight: DCFFontWeight.semibold,
  ),
)
```

### Signals
```dart
final inputValue = signal('');
final navProgress = signal(0.0);

// Read
print(inputValue());

// Write
inputValue.set('new value');
```

## 🚀 What Works

- ✅ Chat list with real tap handlers
- ✅ Push navigation with slide animation
- ✅ Back button navigation
- ✅ Real-time text input (pure signals)
- ✅ Type-safe event payloads
- ✅ Proper DCFlight padding/margins
- ✅ No Flutter APIs!
