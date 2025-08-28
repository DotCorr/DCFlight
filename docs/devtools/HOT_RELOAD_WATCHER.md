# DCFlight Hot Reload Watcher

The DCFlight Hot Reload Watcher provides a stylish, split-terminal interface for development with automatic hot reload detection and triggering.

## Features

### 🎨 Stylish Terminal Interface
- **Split-screen layout**: Flutter logs on the left, watcher info on the right
- **Unicode box drawings**: Clean terminal UI with proper borders and separators
- **Color-coded output**: Different colors for different types of messages
- **Timestamped logs**: All messages include precise timestamps

### 🔥 Intelligent Hot Reload
- **Automatic file watching**: Monitors all `.dart` files in the `lib/` directory recursively
- **Real-time triggers**: Automatically sends 'r' command to Flutter when files change
- **VDOM integration**: Works with the custom DCFlight hot reload system
- **State preservation**: Maintains navigation state and component state during reloads

### 🔧 Smart Process Management
- **Lifecycle coupling**: Watcher automatically dies when Flutter process ends
- **Device auto-selection**: Automatically selects iOS Simulator or first available device
- **Error handling**: Graceful error handling with proper cleanup
- **Interactive pass-through**: User can still interact with Flutter process normally

## Usage

### Start with Hot Reload (Default)
```bash
dcf go
```

### Start without Hot Reload
```bash
dcf go --no-hot-reload
```

### With Additional Flutter Arguments
```bash
dcf go --dcf-args="--release" --dcf-args="--target-platform=ios"
```

### Verbose Output
```bash
dcf go --verbose
```

## Terminal Layout

```
┌──────────────────────────────────────┬─────────────────────────────────────┐
│                Flutter               │              Watcher                │
├──────────────────────────────────────┼─────────────────────────────────────┤
│ 📱 12:34:56 Flutter app starting...   │                    👀 12:34:56 Starting watcher... │
│ 📱 12:34:57 Hot reload completed      │                    📝 12:34:58 File changed: main.dart │
│ ⚠️  12:34:58 Warning: deprecated API │                    🔥 12:34:58 Triggering hot reload... │
└──────────────────────────────────────┴─────────────────────────────────────┘
```

## File Watching Events

The watcher monitors these file system events in the `lib/` directory:

- **📝 File Modified**: Triggers hot reload when existing files are edited
- **➕ File Created**: Triggers hot reload when new files are added
- **🗑️ File Deleted**: Triggers hot reload when files are removed

## Integration with DCFlight VDOM

When files change, the watcher:

1. **Detects the change** via file system events
2. **Logs the event** in the watcher panel (right side)
3. **Sends 'r' command** to the Flutter process
4. **Flutter triggers hot reload** which calls Flutter's reassemble
5. **DCFlight detects the reload** via the `HotReloadDetector`
6. **VDOM re-renders** all components while preserving state

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   File Watcher  │───▶│  Flutter Process │───▶│  DCFlight VDOM  │
│                 │    │                  │    │                 │
│ • Monitors lib/ │    │ • Receives 'r'   │    │ • Detects reload│
│ • Detects chang │    │ • Triggers reload│    │ • Re-renders UI │
│ • Sends command │    │ • Calls reassem  │    │ • Preserves sta │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Error Handling

- **Process failures**: Graceful shutdown with exit code reporting
- **File system errors**: Continues running with error logging
- **Device issues**: Clear error messages with troubleshooting hints
- **Hot reload failures**: Non-blocking errors that don't crash the watcher

## Performance

- **Efficient watching**: Uses native file system events (not polling)
- **Debounced triggers**: Prevents multiple rapid reloads
- **Memory conscious**: Minimal memory footprint for long-running sessions
- **CPU optimized**: Lightweight file monitoring with low CPU usage

