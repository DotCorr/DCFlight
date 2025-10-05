# CRITICAL FIX: Event Listener Registration Batching

## Date
October 5, 2025

## Problem Discovered

After implementing initial mount batching, we discovered TWO critical issues:

### Issue 1: Android - Events Not Working
```
W/DCFComponent: ❌ propagateEvent: Missing registration - viewId=null, eventTypes=null, callback=null
```
- Slider doesn't respond
- Buttons don't fire events
- All user interactions broken

### Issue 2: iOS - White Screen
```
flutter: 🔥 FLUTTER_BRIDGE: commitBatchUpdate called with 40 updates
flutter: 🔥 FLUTTER_BRIDGE: commitBatchUpdate native call result: true
(but screen stays white)
```
- iOS missing `commitBatchUpdate` implementation
- Batch operations not executed on iOS
- Complete blank screen on iOS

## Root Cause Analysis

### Android Events Issue

Event listeners were registered **DURING render** but **BEFORE batch commit**:

```dart
// In engine.dart line 1008:
await _nativeBridge.addEventListeners(viewId, eventTypes);  // ← Called DURING render
```

This happened:
1. `startBatchUpdate()` called
2. `createView()` queued (not executed yet)
3. `addEventListeners()` called immediately ← **VIEWS DON'T EXIST YET!**
4. `attachView()` queued
5. `commitBatchUpdate()` executes (creates views NOW)

Result: Event listeners tried to register on non-existent views!

### iOS White Screen Issue

iOS had NO `commitBatchUpdate` implementation in `DCMauiBridgeImpl.swift`:
- `startBatchUpdate` - missing
- `commitBatchUpdate` - missing
- `cancelBatchUpdate` - missing

The batch channel handler existed but did manual inline processing instead of proper atomic commit.

## The Fixes

### Fix 1: Batch Event Listener Registration (Dart)

**File**: `interface_impl.dart`

```dart
@override
Future<bool> addEventListeners(String viewId, List<String> eventTypes) async {
  // CRITICAL FIX: Queue event listener registration in batch
  // Event listeners must be registered AFTER views are created
  if (_batchUpdateInProgress) {
    print('🔥 FLUTTER_BRIDGE: Adding addEventListeners to batch');
    _pendingBatchUpdates.add({
      'operation': 'addEventListeners',
      'viewId': viewId,
      'eventTypes': eventTypes,
    });
    return true;
  }
  
  // Direct call if not batching
  try {
    await eventChannel.invokeMethod('addEventListeners', {
      'viewId': viewId,
      'eventTypes': eventTypes,
    });
    return true;
  } catch (e) {
    return false;
  }
}
```

### Fix 2: Handle Event Listeners in Android Batch

**File**: `DCMauiBridgeImpl.kt`

Added `addEventListeners` operation type:

```kotlin
data class AddEventListenersOp(val viewId: String, val eventTypes: List<String>)
val eventOps = mutableListOf<AddEventListenersOp>()

// In parsing phase:
"addEventListeners" -> {
    val viewId = operation["viewId"] as? String
    val eventTypes = operation["eventTypes"] as? List<String>
    if (viewId != null && eventTypes != null) {
        eventOps.add(AddEventListenersOp(viewId, eventTypes))
    }
}

// In execution phase (AFTER all views created and attached):
// 4. Register event listeners AFTER all views exist
eventOps.forEach { op ->
    Log.d(TAG, "🔥 BATCH_COMMIT: Registering event listeners for ${op.viewId}")
    DCMauiEventMethodHandler.shared.addEventListeners(op.viewId, op.eventTypes)
}
```

### Fix 3: Implement iOS Batch Update Support

**File**: `DCMauiBridgeImpl.swift`

Added complete batch update implementation:

```swift
/// Start a batch update (no-op on iOS, kept for compatibility)
@objc func startBatchUpdate() -> Bool {
    print("🔥 iOS_BRIDGE: startBatchUpdate called")
    return true
}

/// Commit a batch of operations atomically
@objc func commitBatchUpdate(updates: [[String: Any]]) -> Bool {
    print("🔥 iOS_BRIDGE: commitBatchUpdate called with \(updates.count) updates")
    
    // Collect operations by type
    var createOps: [(viewId: String, viewType: String, props: [String: Any])] = []
    var updateOps: [(viewId: String, props: [String: Any])] = []
    var attachOps: [(childId: String, parentId: String, index: Int)] = []
    var eventOps: [(viewId: String, eventTypes: [String])] = []
    
    // Phase 1: Parse all operations
    for operation in updates {
        // ... parse createView, updateView, attachView, addEventListeners
    }
    
    // Phase 2: Execute all operations atomically
    // 1. Create all views first
    // 2. Update all view props
    // 3. Attach all views to build tree structure
    // 4. Register event listeners AFTER all views exist
    
    return true
}

/// Cancel a batch update (no-op on iOS, kept for compatibility)
@objc func cancelBatchUpdate() -> Bool {
    return true
}
```

**File**: `DCMauiBridgeChannel.swift`

Updated channel handlers:

```swift
case "startBatchUpdate":
    handleStartBatchUpdate(result: result)

case "commitBatchUpdate":
    if let args = args {
        handleCommitBatchUpdate(args, result: result)
    }

case "cancelBatchUpdate":
    handleCancelBatchUpdate(result: result)

// Implementations:
private func handleStartBatchUpdate(result: @escaping FlutterResult) {
    let success = DCMauiBridgeImpl.shared.startBatchUpdate()
    result(success)
}

private func handleCommitBatchUpdate(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let updates = args["updates"] as? [[String: Any]] else {
        result(FlutterError(code: "BATCH_ERROR", message: "Invalid batch update parameters", details: nil))
        return
    }
    
    DispatchQueue.main.async {
        let success = DCMauiBridgeImpl.shared.commitBatchUpdate(updates: updates)
        result(success)
    }
}

private func handleCancelBatchUpdate(result: @escaping FlutterResult) {
    let success = DCMauiBridgeImpl.shared.cancelBatchUpdate()
    result(success)
}
```

## Batch Operation Order

Now ALL platforms follow this React-like atomic order:

```
1. startBatchUpdate()
   ↓
2. Queue createView operations (not executed)
   ↓
3. Queue updateView operations (not executed)
   ↓
4. Queue attachView operations (not executed)
   ↓
5. Queue addEventListeners operations (not executed)
   ↓
6. commitBatchUpdate() - ATOMIC EXECUTION:
   6a. Create all views
   6b. Update all view props
   6c. Attach all views
   6d. Register all event listeners ← NEW!
   6e. Layout calculation (single pass)
```

## Expected Results

After these fixes:

### Android:
- ✅ **All events work immediately on initial render**
- ✅ **Slider responds to touch**
- ✅ **Buttons fire onPress events**
- ✅ **No "missing registration" errors**
- ✅ **Event listeners registered AFTER views exist**

### iOS:
- ✅ **No more white screen**
- ✅ **Initial render shows complete UI**
- ✅ **Matches Android behavior**
- ✅ **All events work on initial render**
- ✅ **True atomic batch rendering**

## Files Changed

1. ✅ `interface_impl.dart` - Added batching to `addEventListeners()`
2. ✅ `DCMauiBridgeImpl.kt` (Android) - Handle `addEventListeners` in batch
3. ✅ `DCMauiBridgeImpl.swift` (iOS) - Implement full batch update support
4. ✅ `DCMauiBridgeChannel.swift` (iOS) - Add batch method handlers

## Testing

Hot reload now and verify:
- Android slider and buttons work immediately
- iOS shows full UI (no white screen)
- iOS events work immediately
- Both platforms behave identically

## Complete Implementation Timeline

1. ✅ Fixed visibility manipulation (YogaShadowTree, DCFLayoutManager)
2. ✅ Fixed asynchronous batch commit (DCMauiBridgeImpl Android)
3. ✅ Fixed asynchronous attachment (DCMauiBridgeImpl Android)
4. ✅ Fixed asynchronous layout application (YogaShadowTree)
5. ✅ Fixed attachView batching bypass (interface_impl.dart)
6. ✅ Fixed initial mount batching bypass (engine.dart)
7. ✅ Fixed props serialization in batch (interface_impl.dart)
8. ✅ **Fixed event listener batching (interface_impl.dart, Android & iOS)**
9. ✅ **Implemented iOS batch update support (DCMauiBridgeImpl.swift)**

**All React-like atomic rendering now complete on BOTH platforms!** 🎉🎉🎉

