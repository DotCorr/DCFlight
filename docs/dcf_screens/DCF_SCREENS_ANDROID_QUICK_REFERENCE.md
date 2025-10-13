# DCF_Screens Android Quick Reference
## Implementation Cheat Sheet

---

## 🎯 Core Classes to Implement

### 1. ScreenContainer.kt
```kotlin
data class ScreenContainer(
    val route: String,
    val presentationStyle: String,
    val content: @Composable () -> Unit,
    val viewId: String,
    var pushConfig: Map<String, Any>? = null,
    var composeView: View? = null
)
```

### 2. DCFScreenRegistry.kt
```kotlin
object DCFScreenRegistry {
    private val routeRegistry = mutableMapOf<String, ScreenContainer>()
    val currentRouteStack = mutableListOf<String>()
    
    fun registerScreen(route: String, container: ScreenContainer)
    fun getScreen(route: String): ScreenContainer?
    fun getAllRoutes(): List<String>
}
```

### 3. DCFStackNavigationBootstrapperComponent.kt
```kotlin
class DCFStackNavigationBootstrapperComponent : DCFComponent {
    companion object {
        lateinit var navController: NavHostController
    }
    
    override fun createView(props: Map<String, Any>): View {
        // Returns ComposeView with NavHost inside
    }
}
```

### 4. DCFScreenComponent.kt
```kotlin
class DCFScreenComponent : DCFComponent {
    override fun createView(props: Map<String, Any>): View {
        // Registers screen in DCFScreenRegistry
    }
    
    override fun updateView(view: View, props: Map<String, Any>): Boolean {
        // Handles navigation commands
    }
    
    private fun navigateToRoute(...)
    private fun popCurrentRoute(...)
    private fun popToRoute(...)
    private fun popToRoot(...)
    private fun replaceCurrentRoute(...)
}
```

---

## 🗺️ Navigation Method Mapping

```kotlin
// iOS: navigationController.pushViewController(vc, animated: true)
// Android:
navController.navigate(targetRoute)

// iOS: navigationController.popViewController(animated: true)
// Android:
navController.popBackStack()

// iOS: navigationController.popToViewController(targetVC, animated: true)
// Android:
navController.popBackStack(targetRoute, inclusive = false)

// iOS: navigationController.popToRootViewController(animated: true)
// Android:
navController.popBackStack(navController.graph.startDestinationId, inclusive = false)

// iOS: Replace current screen
// Android:
navController.navigate(targetRoute) {
    popUpTo(currentRoute) { inclusive = true }
}
```

---

## 🎨 TopAppBar Template

```kotlin
@Composable
fun DCFTopAppBar(
    navController: NavHostController,
    navigationBarStyle: NavigationBarStyle?
) {
    val currentRoute = navController.currentBackStackEntry?.destination?.route
    val screenContainer = currentRoute?.let { DCFScreenRegistry.getScreen(it) }
    val pushConfig = screenContainer?.pushConfig
    
    TopAppBar(
        title = { 
            Text(pushConfig?.get("title") as? String ?: "") 
        },
        navigationIcon = {
            // Back button
            if (navController.previousBackStackEntry != null) {
                IconButton(onClick = { navController.popBackStack() }) {
                    Icon(Icons.Default.ArrowBack, "Back")
                }
            }
        },
        actions = {
            // Right side buttons
            (pushConfig?.get("suffixActions") as? List<Map<String, Any>>)?.forEach { action ->
                IconButton(onClick = { 
                    fireHeaderActionEvent(screenContainer, action)
                }) {
                    Icon(/* icon from action */, action["title"] as? String ?: "")
                }
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = navigationBarStyle?.backgroundColor ?: MaterialTheme.colorScheme.primary
        )
    )
}
```

---

## 🔄 Lifecycle Events

```kotlin
@Composable
fun DCFScreenContent(route: String, navController: NavHostController) {
    val screenContainer = DCFScreenRegistry.getScreen(route)
    
    DisposableEffect(route) {
        // onAppear
        fireLifecycleEvent(screenContainer, "onAppear", mapOf("route" to route))
        
        onDispose {
            // onDisappear
            fireLifecycleEvent(screenContainer, "onDisappear", mapOf("route" to route))
        }
    }
    
    // Render DCFlight content
    screenContainer?.content?.invoke()
}

fun fireLifecycleEvent(
    screenContainer: ScreenContainer?,
    eventName: String,
    data: Map<String, Any>
) {
    screenContainer?.composeView?.let { view ->
        propagateEvent(on = view, eventName = eventName, data = data)
    }
}
```

---

## 🎯 SF Symbol → Material Icon Mapping

```kotlin
fun mapSFSymbolToMaterialIcon(symbolName: String?): ImageVector {
    return when (symbolName) {
        "magnifyingglass" -> Icons.Default.Search
        "plus" -> Icons.Default.Add
        "minus" -> Icons.Default.Remove
        "person" -> Icons.Default.Person
        "person.circle" -> Icons.Default.AccountCircle
        "gear" -> Icons.Default.Settings
        "heart" -> Icons.Default.Favorite
        "heart.fill" -> Icons.Default.Favorite
        "star" -> Icons.Default.Star
        "star.fill" -> Icons.Default.Star
        "trash" -> Icons.Default.Delete
        "pencil" -> Icons.Default.Edit
        "checkmark" -> Icons.Default.Check
        "xmark" -> Icons.Default.Close
        "ellipsis" -> Icons.Default.MoreVert
        "arrow.left" -> Icons.Default.ArrowBack
        "arrow.right" -> Icons.Default.ArrowForward
        "arrow.up" -> Icons.Default.ArrowUpward
        "arrow.down" -> Icons.Default.ArrowDownward
        "chevron.left" -> Icons.Default.ChevronLeft
        "chevron.right" -> Icons.Default.ChevronRight
        "house" -> Icons.Default.Home
        "envelope" -> Icons.Default.Email
        "phone" -> Icons.Default.Phone
        "camera" -> Icons.Default.Camera
        "photo" -> Icons.Default.Image
        "location" -> Icons.Default.LocationOn
        "map" -> Icons.Default.Map
        "calendar" -> Icons.Default.CalendarToday
        "clock" -> Icons.Default.Schedule
        "bell" -> Icons.Default.Notifications
        "bookmark" -> Icons.Default.Bookmark
        "folder" -> Icons.Default.Folder
        "doc" -> Icons.Default.Description
        "lock" -> Icons.Default.Lock
        "key" -> Icons.Default.Key
        "cart" -> Icons.Default.ShoppingCart
        "creditcard" -> Icons.Default.CreditCard
        else -> Icons.Default.Info  // Fallback
    }
}
```

---

## 📦 Gradle Dependencies

```groovy
// Already in your build.gradle:
implementation platform('androidx.compose:compose-bom:2025.10.00')
implementation 'androidx.compose.ui:ui'
implementation 'androidx.compose.ui:ui-tooling-preview'
implementation 'androidx.compose.material3:material3'
implementation 'androidx.compose.material:material-icons-extended'
implementation 'androidx.navigation:navigation-compose:2.8.3'
implementation 'androidx.activity:activity-compose:1.9.2'
implementation 'androidx.lifecycle:lifecycle-viewmodel-compose:2.8.5'
```

---

## 🚀 Implementation Order

1. **ScreenContainer.kt** - 15 mins
2. **DCFScreenRegistry.kt** - 20 mins
3. **DCFScreenComponent.kt** - 2 hours
   - createView() - screen registration
   - updateView() - command handling
   - navigateToRoute()
   - popCurrentRoute()
   - popToRoute()
   - popToRoot()
   - replaceCurrentRoute()
4. **DCFStackNavigationBootstrapperComponent.kt** - 3 hours
   - ComposeView setup
   - NavHost configuration
   - DCFNavigationHost composable
   - DCFTopAppBar composable
   - Retry logic
5. **DCFScreenContent.kt** - 1 hour
   - Lifecycle effects
   - Content rendering
6. **Helper functions** - 1 hour
   - SF Symbol mapping
   - Event propagation
   - Config extraction

**Total Estimated Time**: 1 day (8 hours)

---

## 🧪 Testing Strategy

### Test 1: Basic Navigation
```dart
// In Dart app
AppNavigation.navigateTo("details");
// Expected: Navigate to details screen
```

### Test 2: Pop Back
```dart
AppNavigation.goBack();
// Expected: Return to previous screen
```

### Test 3: TopAppBar
```dart
DCFPushConfig(
  title: "Test Screen",
  suffixActions: [
    DCFPushHeaderActionConfig.withSFSymbol(
      title: "Add",
      symbolName: "plus",
      actionId: "add_action",
    ),
  ],
)
// Expected: See "Test Screen" title and + button in TopAppBar
```

### Test 4: Header Action
```dart
onHeaderActionPress: (data) {
  print("Action pressed: ${data['actionId']}");
}
// Expected: Print "Action pressed: add_action" when + button tapped
```

### Test 5: Lifecycle Events
```dart
onAppear: (data) {
  print("Screen appeared: ${data['route']}");
}
onDisappear: (data) {
  print("Screen disappeared: ${data['route']}");
}
// Expected: See logs when navigating between screens
```

---

## ⚠️ Common Pitfalls

### 1. NavController Not Initialized
```kotlin
// WRONG: navController accessed before setContent
navController.navigate("details")

// RIGHT: Ensure navController is initialized in Composable
val navController = rememberNavController()
DCFStackNavigationBootstrapperComponent.navController = navController
```

### 2. Screen Not Registered
```kotlin
// Check if screen exists before navigating
val targetContainer = DCFScreenRegistry.getScreen(targetRoute)
if (targetContainer == null) {
    Log.e(TAG, "Screen $targetRoute not registered yet")
    return
}
```

### 3. AndroidView in Compose
```kotlin
// DCFlight renders to Android View, wrap it:
@Composable
fun DCFScreenContent(route: String) {
    val dcflightView = screenContainer?.composeView
    
    AndroidView(
        factory = { dcflightView ?: View(it) },
        modifier = Modifier.fillMaxSize()
    )
}
```

### 4. Lifecycle Events Not Firing
```kotlin
// Make sure propagateEvent is called with correct View
screenContainer.composeView?.let { androidView ->
    propagateEvent(
        on = androidView,  // Must be the actual DCFlight Android View
        eventName = "onAppear",
        data = mapOf("route" to route)
    )
}
```

---

## 📝 File Structure

```
android/src/main/kotlin/com/dotcorr/dcfscreens/
├── DcfScreensPlugin.kt (Flutter plugin entry)
├── components/
│   ├── navigation/
│   │   ├── DCFScreenComponent.kt
│   │   ├── DCFStackNavigationBootstrapperComponent.kt
│   │   ├── ScreenContainer.kt
│   │   ├── DCFScreenRegistry.kt
│   │   ├── composables/
│   │   │   ├── DCFNavigationHost.kt
│   │   │   ├── DCFTopAppBar.kt
│   │   │   ├── DCFScreenContent.kt
│   │   │   └── HeaderActionButton.kt
│   │   └── utils/
│   │       ├── NavigationBarStyle.kt
│   │       ├── SFSymbolMapper.kt
│   │       └── LifecycleEventHelper.kt
```

---

## 🎓 Key Takeaways

1. **1:1 Parity**: Every iOS concept has direct Android equivalent
2. **Compose ≠ UIKit**: Declarative vs Imperative, but same result
3. **Registry Pattern**: Same global registry as iOS
4. **Lifecycle**: DisposableEffect replaces viewWillAppear/viewDidDisappear
5. **TopAppBar**: Compose version of UINavigationItem
6. **NavController**: Compose version of UINavigationController
7. **AndroidView**: Bridge between DCFlight Views and Compose

---

**Ready to implement!** 🚀

Start with `ScreenContainer.kt` and work your way through the checklist.

