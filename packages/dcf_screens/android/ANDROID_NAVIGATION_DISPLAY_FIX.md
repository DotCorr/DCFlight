# Android Navigation Display Fix - Z-Index Solution

## Problem
Android was showing the home screen instead of the initial screen (profile) even though the navigation system correctly registered profile as the initial route.

## Root Cause
**Different Architecture: iOS vs Android**

### iOS Architecture:
- Uses `UINavigationController` (native navigation container)
- Initial screen's view controller is set as root: `navigationController.setViewControllers([screenVC], animated: false)`
- Navigation controller manages the view hierarchy and display
- Bootstrapper returns a hidden placeholder view

### Android Architecture (DCFlight):
- **All screens are sibling FrameLayouts attached to root ViewGroup**
- No native navigation controller - screens are managed manually
- **Z-order (stacking order) determines visibility:**
  - First child (index 0) = bottom layer
  - Last child (highest index) = top layer (visible)

## The Bug
Initial attachment order from batch system:
```
1. Home screen → root index 0 (bottom)
2. Profile screen → root index 1
3. Settings screen → root index 2
4. ...other screens...
5. Bootstrapper → root index 1 (inserted, pushing everything after it down!)
```

**Final hierarchy after batch:**
```
- Index 0: Home (bottom) ← VISIBLE because nothing on top!
- Index 1: Bootstrapper (transparent/empty)
- Index 2: Profile (should be visible but isn't!)
- Index 3+: Other screens
```

**Why home was visible:** It was at index 0, and no other opaque view was on top!

## Previous Failed Fix Attempt
The bootstrapper tried to manually add the profile screen:
```kotlin
container.addView(screenFrameLayout, FrameLayout.LayoutParams(...))
```

**This failed because:**
1. Bridge's batch system ALSO attached screens to root
2. When batch executed: `(parent as? ViewGroup)?.removeView(screenFrameLayout)`
3. Profile was removed from bootstrapper and attached to root
4. Final result: Profile at wrong Z-index, home screen visible

## The Solution
**Don't fight the batch system - work with it!**

The bootstrapper should:
1. ❌ **NOT** manually add screens to itself
2. ✅ **DO** register the initial route with navigation registry
3. ✅ **DO** bring initial screen to front AFTER batch attachment

### Implementation:
```kotlin
private fun setupInitialScreenWithRetry(...) {
    val screenContainer = DCFScreenRegistry.getScreen(initialScreen)
    if (screenContainer != null && screenContainer.frameLayout != null) {
        DCFScreenRegistry.pushRoute(initialScreen)
        
        // CRITICAL: Don't manually add to container!
        // Bridge will attach all screens to root.
        // Instead, bring initial screen to front (highest Z-index)
        val screenFrameLayout = screenContainer.frameLayout!!
        
        Handler(Looper.getMainLooper()).post {
            screenFrameLayout.bringToFront() // Move to highest index
            screenFrameLayout.requestLayout() // Trigger layout update
        }
        
        return
    }
    // ... retry logic
}
```

### How `bringToFront()` works:
- Moves the view to the last position in its parent's child list
- Makes it the topmost view (highest Z-index)
- Result: Profile screen is now visible on top of everything!

## Final Hierarchy After Fix:
```
- Index 0: Home
- Index 1: Bootstrapper  
- Index 2: Settings
- Index 3: ...other screens...
- Index N (last): Profile ← VISIBLE! (brought to front)
```

## Key Learnings
1. **Android ViewGroup children are Z-ordered by index**
   - First child = bottom layer
   - Last child = top layer (visible)

2. **DCFlight uses sibling architecture, not nested controllers**
   - All screens are siblings in root ViewGroup
   - iOS uses nested view controllers in UINavigationController

3. **Don't fight the bridge's batch attachment system**
   - Let it attach views to root
   - Use `bringToFront()` to control visibility

4. **Timing matters:**
   - `bringToFront()` must be called AFTER view is attached to parent
   - Use `Handler.post {}` to ensure it runs after batch completes

## Testing
After this fix:
1. ✅ Initial screen (profile) should be visible on launch
2. ✅ Navigation buttons should work
3. ✅ No white screen
4. ✅ No "is not a ViewGroup" errors
