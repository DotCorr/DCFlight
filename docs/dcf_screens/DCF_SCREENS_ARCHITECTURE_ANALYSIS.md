# DCF_Screens Architecture Analysis
## iOS Implementation → Android Compose Navigation Mapping

**Date**: October 13, 2025  
**Focus**: Screen API architecture for 1:1 Android implementation using Jetpack Compose Navigation

---

## 📋 Executive Summary

DCF_Screens provides **native stack-based navigation** with a declarative API. The iOS implementation uses `UINavigationController`, and Android should mirror this using **Jetpack Compose Navigation** with `NavController`.

### Key Architecture Principles

1. **Declarative Screen Registration** - Screens register themselves globally
2. **Route-Based Navigation** - Navigate by route strings, not objects
3. **Lifecycle Management** - Proper appear/disappear/activate/deactivate events
4. **Platform Parity** - Same API works identically on both platforms
5. **Native Integration** - Uses native navigation patterns (UIKit on iOS, Compose on Android)

---

## 🏗️ Core Architecture

### 1. Dart API Layer (Platform-Agnostic)

```dart
// Entry point - Stack Navigation Root
DCFStackNavigationRoot(
  initialScreen: "home",
  screenRegistryComponents: ScreenRegistry(),
  navigationBarStyle: DCFNavigationBarStyle(...),
  onNavigationChange: (data) { },
  onBackPressed: (data) { },
)
```

**Components**:
- `DCFStackNavigationRoot` - Top-level container
- `DCFStackNavigationBootstrapper` - Internal component that creates native navigation controller
- `DCFScreen` - Individual screen component
- `AppNavigation` - Global navigation API (navigateTo, goBack, replace, etc.)

---

### 2. Screen Registration Pattern

#### Dart Side
```dart
class ScreenRegistry extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFFragment(children: [
      DCFScreen(
        route: "home",
        presentationStyle: DCFPresentationStyle.push,
        builder: () => HomeScreen(),
        pushConfig: DCFPushConfig(
          title: "Home",
          prefixActions: [...],  // Left bar buttons
          suffixActions: [...],  // Right bar buttons
        ),
      ),
      DCFScreen(
        route: "details",
        presentationStyle: DCFPresentationStyle.push,
        builder: () => DetailsScreen(),
      ),
    ]);
  }
}
```

**Key Concepts**:
- Screens register **before** navigation happens
- Each screen has a unique `route` identifier
- Screens can be **push** (stack), **modal**, **sheet**, **popover**, **tab**
- Screens have optional configs for their presentation style

---

### 3. iOS Implementation Deep Dive

#### A. ScreenContainer (Core Data Structure)

```swift
class ScreenContainer {
    let route: String                     // e.g., "home", "details"
    let presentationStyle: String         // e.g., "push", "modal"
    let viewController: UIViewController  // Native iOS view controller
    let contentView: UIView              // DCFlight VDOM renders here
    
    init(route: String, presentationStyle: String) {
        self.route = route
        self.presentationStyle = presentationStyle
        self.viewController = UIViewController()
        self.contentView = UIView()
        self.viewController.view = contentView
    }
}
```

**Purpose**: Bridge between DCFlight's VDOM and UIKit's view controller system

#### B. Global Registry

```swift
// Inside DCFScreenComponent
static var routeRegistry: [String: ScreenContainer] = [:]
static var currentRouteStack: [String] = []
```

**Purpose**: 
- `routeRegistry` - Maps route strings to ScreenContainer instances
- `currentRouteStack` - Tracks navigation history for back button handling

#### C. DCFStackNavigationBootstrapper

**Responsibilities**:
1. Create `UINavigationController` 
2. Set as root window controller
3. Configure navigation bar style
4. Load initial screen with retry logic
5. Setup lifecycle event handlers

**Key Code Pattern**:
```swift
func createView(props: [String: Any]) -> UIView {
    let navigationController = UINavigationController()
    
    configureNavigationBarStyle(navigationController, props: props)
    
    setupInitialScreenWithRetry(
        navigationController, 
        initialScreen: props["initialScreen"],
        retryCount: 0, 
        maxRetries: 10
    )
    
    DispatchQueue.main.async {
        replaceRoot(controller: navigationController)
    }
    
    return placeholderView  // Hidden view for DCFlight VDOM
}
```

#### D. DCFScreenComponent

**Responsibilities**:
1. Register screens in global registry
2. Create `ScreenContainer` for each screen
3. Handle navigation commands (push, pop, replace, modal)
4. Configure navigation bar items (title, buttons)
5. Fire lifecycle events (onAppear, onDisappear, etc.)

**Key Methods**:

```swift
// Screen Registration
func createView(props: [String: Any]) -> UIView {
    let route = props["route"] as! String
    let presentationStyle = props["presentationStyle"] as! String
    
    let screenContainer = ScreenContainer(route: route, presentationStyle: presentationStyle)
    DCFScreenComponent.routeRegistry[route] = screenContainer
    
    configureScreen(screenContainer, props: props)
    return screenContainer.contentView
}

// Navigation - Push
func navigateToRoute(_ targetRoute: String, animated: Bool, params: [String: Any]?) {
    guard let targetContainer = routeRegistry[targetRoute] else { return }
    guard let navigationController = getCurrentActiveNavigationController() else { return }
    
    configureScreenForPush(targetContainer)
    navigationController.pushViewController(targetContainer.viewController, animated: animated)
    updateRouteStack(navigationController)
}

// Navigation - Pop
func popCurrentRoute(animated: Bool) {
    guard let navigationController = getCurrentActiveNavigationController() else { return }
    navigationController.popViewController(animated: animated)
}

// Navigation - Replace
func replaceCurrentRoute(with targetRoute: String, animated: Bool) {
    guard let targetContainer = routeRegistry[targetRoute] else { return }
    guard let navigationController = getCurrentActiveNavigationController() else { return }
    
    var viewControllers = navigationController.viewControllers
    if !viewControllers.isEmpty {
        viewControllers[viewControllers.count - 1] = targetContainer.viewController
    }
    navigationController.setViewControllers(viewControllers, animated: animated)
}
```

#### E. Push Configuration (Navigation Bar)

```swift
func configureScreenForPush(_ screenContainer: ScreenContainer) {
    guard let pushConfig = objc_getAssociatedObject(
        screenContainer.viewController,
        UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!
    ) as? [String: Any] else { return }
    
    let viewController = screenContainer.viewController
    
    // Title
    if let title = pushConfig["title"] as? String {
        viewController.navigationItem.title = title
    }
    
    // Back button
    let hideBackButton = pushConfig["hideBackButton"] as? Bool ?? false
    viewController.navigationItem.hidesBackButton = hideBackButton
    
    // Header actions (left/right bar buttons)
    if let prefixActions = pushConfig["prefixActions"] as? [[String: Any]] {
        let leftBarButtonItems = createBarButtonItems(from: prefixActions, for: viewController, position: .left)
        viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
    }
    
    if let suffixActions = pushConfig["suffixActions"] as? [[String: Any]] {
        let rightBarButtonItems = createBarButtonItems(from: suffixActions, for: viewController, position: .right)
        viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
    }
}
```

#### F. Lifecycle Events

```swift
// When screen appears
propagateEvent(
    on: screenContainer.contentView,
    eventName: "onAppear",
    data: ["route": route]
)

// When screen disappears
propagateEvent(
    on: screenContainer.contentView,
    eventName: "onDisappear",
    data: ["route": route]
)

// When receiving navigation params
propagateEvent(
    on: screenContainer.contentView,
    eventName: "onReceiveParams",
    data: ["params": params, "sourceRoute": sourceRoute]
)

// When header button pressed
propagateEvent(
    on: screenContainer.contentView,
    eventName: "onHeaderActionPress",
    data: ["actionId": actionId, "title": title, "route": route]
)
```

---

## 🤖 Android Implementation Blueprint

### Architecture Overview

**Replace iOS UIKit concepts with Compose equivalents:**

| iOS UIKit | Android Compose Navigation |
|-----------|---------------------------|
| `UINavigationController` | `NavHostController` |
| `UIViewController` | Composable function |
| `navigationItem.title` | TopAppBar title |
| `leftBarButtonItems` | TopAppBar navigationIcon |
| `rightBarButtonItems` | TopAppBar actions |
| `pushViewController` | `navController.navigate(route)` |
| `popViewController` | `navController.popBackStack()` |
| `replaceViewController` | `navController.navigate(route) { popUpTo(...) { inclusive = true } }` |

---

### 1. ScreenContainer (Kotlin/Compose)

```kotlin
/**
 * Container holding screen metadata and Compose content
 * Equivalent to iOS ScreenContainer
 */
data class ScreenContainer(
    val route: String,
    val presentationStyle: String,
    val content: @Composable () -> Unit,  // Composable instead of UIView
    val viewId: String,  // DCFlight VDOM view ID
    var pushConfig: Map<String, Any>? = null,
    var modalConfig: Map<String, Any>? = null
) {
    // Store reference to the AndroidComposeView that holds DCFlight content
    var composeView: View? = null
}
```

---

### 2. Global Registry (Kotlin)

```kotlin
object DCFScreenRegistry {
    // Maps route -> ScreenContainer
    private val routeRegistry = mutableMapOf<String, ScreenContainer>()
    
    // Current navigation stack (for back button tracking)
    val currentRouteStack = mutableListOf<String>()
    
    fun registerScreen(route: String, container: ScreenContainer) {
        routeRegistry[route] = container
        Log.d(TAG, "📝 Registered screen: $route")
    }
    
    fun getScreen(route: String): ScreenContainer? {
        return routeRegistry[route]
    }
    
    fun getAllRoutes(): List<String> {
        return routeRegistry.keys.toList()
    }
    
    fun cleanup() {
        routeRegistry.clear()
        currentRouteStack.clear()
    }
}
```

---

### 3. DCFStackNavigationBootstrapperComponent (Kotlin)

```kotlin
/**
 * Creates NavHost and sets up initial navigation
 * Equivalent to iOS DCFStackNavigationBootstrapperComponent
 */
class DCFStackNavigationBootstrapperComponent : DCFComponent {
    
    companion object {
        private const val TAG = "DCFStackNavBootstrapper"
        
        // Store NavController for global navigation
        lateinit var navController: NavHostController
    }
    
    override fun createView(props: Map<String, Any>): View {
        Log.d(TAG, "🔧 Setting up stack navigation root")
        
        val initialScreen = props["initialScreen"] as? String ?: "home"
        val context = /* Get from DCMauiBridgeImpl context */
        
        // Create ComposeView that hosts NavHost
        val composeView = ComposeView(context).apply {
            setContent {
                // Remember NavController
                navController = rememberNavController()
                
                // Apply navigation bar style
                val navBarStyle = extractNavigationBarStyle(props)
                
                // Setup NavHost with all registered screens
                DCFNavigationHost(
                    navController = navController,
                    initialScreen = initialScreen,
                    navigationBarStyle = navBarStyle,
                    onNavigationChange = props["onNavigationChange"] as? (Map<*, *>) -> Unit,
                    onBackPressed = props["onBackPressed"] as? (Map<*, *>) -> Unit
                )
            }
        }
        
        // Setup retry logic for initial screen (like iOS)
        setupInitialScreenWithRetry(initialScreen, retryCount = 0, maxRetries = 10)
        
        return composeView
    }
    
    @Composable
    private fun DCFNavigationHost(
        navController: NavHostController,
        initialScreen: String,
        navigationBarStyle: NavigationBarStyle?,
        onNavigationChange: ((Map<*, *>) -> Unit)?,
        onBackPressed: ((Map<*, *>) -> Unit)?
    ) {
        Scaffold(
            topBar = {
                // TopAppBar configured per screen
                DCFTopAppBar(
                    navController = navController,
                    navigationBarStyle = navigationBarStyle
                )
            }
        ) { paddingValues ->
            NavHost(
                navController = navController,
                startDestination = initialScreen,
                modifier = Modifier.padding(paddingValues)
            ) {
                // Dynamically add all registered screens
                DCFScreenRegistry.getAllRoutes().forEach { route ->
                    composable(route) {
                        DCFScreenContent(route = route, navController = navController)
                    }
                }
            }
        }
        
        // Setup back press handler
        BackHandler {
            onBackPressed?.invoke(mapOf("route" to navController.currentBackStackEntry?.destination?.route))
            navController.popBackStack()
        }
    }
    
    @Composable
    private fun DCFTopAppBar(
        navController: NavHostController,
        navigationBarStyle: NavigationBarStyle?
    ) {
        val currentRoute = navController.currentBackStackEntry?.destination?.route
        val screenContainer = currentRoute?.let { DCFScreenRegistry.getScreen(it) }
        val pushConfig = screenContainer?.pushConfig
        
        TopAppBar(
            title = { Text(pushConfig?.get("title") as? String ?: "") },
            navigationIcon = {
                // Back button or custom prefix actions
                if (navController.previousBackStackEntry != null) {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
                
                // Custom prefix actions (left bar buttons)
                pushConfig?.get("prefixActions")?.let { actions ->
                    // Render custom action buttons
                }
            },
            actions = {
                // Suffix actions (right bar buttons)
                pushConfig?.get("suffixActions")?.let { actions ->
                    (actions as? List<Map<String, Any>>)?.forEach { action ->
                        IconButton(onClick = { 
                            fireHeaderActionEvent(screenContainer, action)
                        }) {
                            // Render icon from action config
                            RenderActionIcon(action)
                        }
                    }
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = navigationBarStyle?.backgroundColor ?: MaterialTheme.colorScheme.primary,
                titleContentColor = navigationBarStyle?.titleColor ?: MaterialTheme.colorScheme.onPrimary
            )
        )
    }
}
```

---

### 4. DCFScreenComponent (Kotlin)

```kotlin
/**
 * Registers screens and provides navigation methods
 * Equivalent to iOS DCFScreenComponent
 */
class DCFScreenComponent : DCFComponent {
    
    companion object {
        private const val TAG = "DCFScreenComponent"
    }
    
    override fun createView(props: Map<String, Any>): View {
        val route = props["route"] as? String ?: return View(context)
        val presentationStyle = props["presentationStyle"] as? String ?: "push"
        
        Log.d(TAG, "🔧 Creating screen for route '$route' with style '$presentationStyle'")
        
        // Get the DCFlight VDOM content view (already rendered by engine)
        val contentView = /* Get from ViewRegistry - this is the DCFlight rendered content */
        
        // Create ScreenContainer
        val screenContainer = ScreenContainer(
            route = route,
            presentationStyle = presentationStyle,
            content = {
                // Wrap DCFlight Android view in Compose
                AndroidView(factory = { contentView })
            },
            viewId = /* Generate or extract from props */
        )
        
        // Store push/modal configs
        configureScreen(screenContainer, props)
        
        // Register globally
        DCFScreenRegistry.registerScreen(route, screenContainer)
        
        Log.d(TAG, "✅ Registered screen: $route")
        
        // Return placeholder view (screen will be shown via navigation)
        return View(context).apply {
            visibility = View.GONE
        }
    }
    
    override fun updateView(view: View, props: Map<String, Any>): Boolean {
        val route = props["route"] as? String ?: return false
        val screenContainer = DCFScreenRegistry.getScreen(route) ?: return false
        
        // Update configs
        configureScreen(screenContainer, props)
        
        // Handle navigation commands
        handleRouteNavigationCommand(screenContainer, props)
        
        return true
    }
    
    private fun configureScreen(screenContainer: ScreenContainer, props: Map<String, Any>) {
        // Store push config
        props["pushConfig"]?.let { config ->
            screenContainer.pushConfig = config as? Map<String, Any>
        }
        
        // Store modal config
        props["modalConfig"]?.let { config ->
            screenContainer.modalConfig = config as? Map<String, Any>
        }
    }
    
    private fun handleRouteNavigationCommand(screenContainer: ScreenContainer, props: Map<String, Any>) {
        val commandData = props["routeNavigationCommand"] as? Map<String, Any> ?: return
        
        Log.d(TAG, "🚀 Processing navigation command for '${screenContainer.route}': $commandData")
        
        val navController = DCFStackNavigationBootstrapperComponent.navController
        
        // Navigate to route
        commandData["navigateToRoute"]?.let { targetRoute ->
            val animated = commandData["animated"] as? Boolean ?: true
            val params = commandData["params"] as? Map<String, Any>
            navigateToRoute(targetRoute as String, animated, params, screenContainer)
        }
        
        // Pop
        commandData["pop"]?.let { popData ->
            val animated = (popData as? Map<*, *>)?.get("animated") as? Boolean ?: true
            val result = (popData as? Map<*, *>)?.get("result") as? Map<String, Any>
            popCurrentRoute(animated, result, screenContainer)
        }
        
        // Pop to route
        commandData["popToRoute"]?.let { targetRoute ->
            val animated = commandData["animated"] as? Boolean ?: true
            popToRoute(targetRoute as String, animated, screenContainer)
        }
        
        // Pop to root
        commandData["popToRoot"]?.let { popToRootData ->
            val animated = (popToRootData as? Map<*, *>)?.get("animated") as? Boolean ?: true
            popToRoot(animated, screenContainer)
        }
        
        // Replace
        commandData["replaceWithRoute"]?.let { replaceData ->
            val data = replaceData as? Map<*, *>
            val targetRoute = data?.get("route") as? String ?: return
            val animated = data["animated"] as? Boolean ?: true
            val params = data["params"] as? Map<String, Any>
            replaceCurrentRoute(targetRoute, animated, params, screenContainer)
        }
        
        // Modal
        commandData["presentModalRoute"]?.let { modalData ->
            val data = modalData as? Map<*, *>
            val targetRoute = data?.get("route") as? String ?: return
            val animated = data["animated"] as? Boolean ?: true
            val params = data["params"] as? Map<String, Any>
            presentModal(targetRoute, animated, params, screenContainer)
        }
    }
    
    // Navigation Methods
    
    private fun navigateToRoute(
        targetRoute: String,
        animated: Boolean,
        params: Map<String, Any>?,
        sourceContainer: ScreenContainer
    ) {
        val targetContainer = DCFScreenRegistry.getScreen(targetRoute)
        if (targetContainer == null) {
            Log.e(TAG, "❌ Route '$targetRoute' not found in registry")
            return
        }
        
        val navController = DCFStackNavigationBootstrapperComponent.navController
        
        // Fire params event
        params?.let {
            fireLifecycleEvent(
                targetContainer,
                "onReceiveParams",
                mapOf("params" to it, "sourceRoute" to sourceContainer.route)
            )
        }
        
        // Navigate
        navController.navigate(targetRoute) {
            // Configure navigation options
            launchSingleTop = false
        }
        
        // Update stack
        DCFScreenRegistry.currentRouteStack.add(targetRoute)
        
        Log.d(TAG, "✅ Navigated to route '$targetRoute'")
    }
    
    private fun popCurrentRoute(
        animated: Boolean,
        result: Map<String, Any>?,
        sourceContainer: ScreenContainer
    ) {
        val navController = DCFStackNavigationBootstrapperComponent.navController
        
        // Send result to previous screen
        result?.let {
            val previousRoute = navController.previousBackStackEntry?.destination?.route
            previousRoute?.let { route ->
                DCFScreenRegistry.getScreen(route)?.let { container ->
                    fireLifecycleEvent(container, "onReceiveResult", mapOf("result" to it))
                }
            }
        }
        
        navController.popBackStack()
        
        if (DCFScreenRegistry.currentRouteStack.isNotEmpty()) {
            DCFScreenRegistry.currentRouteStack.removeAt(DCFScreenRegistry.currentRouteStack.size - 1)
        }
        
        Log.d(TAG, "✅ Popped current route")
    }
    
    private fun popToRoute(
        targetRoute: String,
        animated: Boolean,
        sourceContainer: ScreenContainer
    ) {
        val navController = DCFStackNavigationBootstrapperComponent.navController
        
        navController.popBackStack(targetRoute, inclusive = false)
        
        // Update stack
        val targetIndex = DCFScreenRegistry.currentRouteStack.indexOf(targetRoute)
        if (targetIndex >= 0) {
            DCFScreenRegistry.currentRouteStack.subList(targetIndex + 1, DCFScreenRegistry.currentRouteStack.size).clear()
        }
        
        Log.d(TAG, "✅ Popped to route '$targetRoute'")
    }
    
    private fun popToRoot(animated: Boolean, sourceContainer: ScreenContainer) {
        val navController = DCFStackNavigationBootstrapperComponent.navController
        
        // Pop to start destination
        navController.popBackStack(navController.graph.startDestinationId, inclusive = false)
        
        // Clear stack (keep only root)
        if (DCFScreenRegistry.currentRouteStack.isNotEmpty()) {
            val rootRoute = DCFScreenRegistry.currentRouteStack[0]
            DCFScreenRegistry.currentRouteStack.clear()
            DCFScreenRegistry.currentRouteStack.add(rootRoute)
        }
        
        Log.d(TAG, "✅ Popped to root")
    }
    
    private fun replaceCurrentRoute(
        targetRoute: String,
        animated: Boolean,
        params: Map<String, Any>?,
        sourceContainer: ScreenContainer
    ) {
        val navController = DCFStackNavigationBootstrapperComponent.navController
        
        // Navigate and pop current screen
        navController.navigate(targetRoute) {
            popUpTo(navController.currentBackStackEntry?.destination?.route ?: return@navigate) {
                inclusive = true
            }
        }
        
        // Update stack
        if (DCFScreenRegistry.currentRouteStack.isNotEmpty()) {
            DCFScreenRegistry.currentRouteStack[DCFScreenRegistry.currentRouteStack.size - 1] = targetRoute
        }
        
        Log.d(TAG, "✅ Replaced with route '$targetRoute'")
    }
    
    private fun presentModal(
        targetRoute: String,
        animated: Boolean,
        params: Map<String, Any>?,
        sourceContainer: ScreenContainer
    ) {
        // For modal presentation in Compose, use Dialog or ModalBottomSheet
        // This requires different composable setup
        
        val navController = DCFStackNavigationBootstrapperComponent.navController
        navController.navigate(targetRoute)
        
        Log.d(TAG, "✅ Presented modal route '$targetRoute'")
    }
    
    // Lifecycle Events
    
    private fun fireLifecycleEvent(
        screenContainer: ScreenContainer,
        eventName: String,
        data: Map<String, Any>
    ) {
        screenContainer.composeView?.let { view ->
            propagateEvent(
                on = view,
                eventName = eventName,
                data = data
            )
        }
        
        Log.d(TAG, "📡 Fired '$eventName' event for route '${screenContainer.route}'")
    }
}
```

---

### 5. DCFScreenContent Composable

```kotlin
/**
 * Composable that renders DCFlight content for a specific route
 * This bridges Compose Navigation with DCFlight's Android View system
 */
@Composable
fun DCFScreenContent(
    route: String,
    navController: NavHostController
) {
    val screenContainer = DCFScreenRegistry.getScreen(route)
    
    if (screenContainer == null) {
        // Fallback UI
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Text("Screen '$route' not found")
        }
        return
    }
    
    // Lifecycle effects
    DisposableEffect(route) {
        // onAppear
        fireLifecycleEvent(screenContainer, "onAppear", mapOf("route" to route))
        
        onDispose {
            // onDisappear
            fireLifecycleEvent(screenContainer, "onDisappear", mapOf("route" to route))
        }
    }
    
    // Render DCFlight content
    screenContainer.content()
}
```

---

## 📊 Navigation API Mapping

### Push Navigation

| Dart API | iOS Implementation | Android Implementation |
|----------|-------------------|------------------------|
| `AppNavigation.navigateTo("details")` | `navigationController.pushViewController(vc, animated: true)` | `navController.navigate("details")` |
| `AppNavigation.navigateToInstant("details")` | `navigationController.pushViewController(vc, animated: false)` | `navController.navigate("details")` (instant) |

### Pop Navigation

| Dart API | iOS Implementation | Android Implementation |
|----------|-------------------|------------------------|
| `AppNavigation.goBack()` | `navigationController.popViewController(animated: true)` | `navController.popBackStack()` |
| `AppNavigation.popToRoute("home")` | `navigationController.popToViewController(homeVC, animated: true)` | `navController.popBackStack("home", inclusive: false)` |
| `AppNavigation.goToRoot()` | `navigationController.popToRootViewController(animated: true)` | `navController.popBackStack(startDestId, inclusive: false)` |

### Replace Navigation

| Dart API | iOS Implementation | Android Implementation |
|----------|-------------------|------------------------|
| `AppNavigation.replace("profile")` | `navigationController.setViewControllers([...existing, profileVC], animated: true)` | `navController.navigate("profile") { popUpTo(current) { inclusive = true } }` |

---

## 🎨 TopAppBar Configuration

### Dart API
```dart
DCFPushConfig(
  title: "Details",
  hideBackButton: false,
  prefixActions: [
    DCFPushHeaderActionConfig.withSFSymbol(
      title: "Search",
      symbolName: "magnifyingglass",
      actionId: "search",
    ),
  ],
  suffixActions: [
    DCFPushHeaderActionConfig.withSFSymbol(
      title: "Add",
      symbolName: "plus",
      actionId: "add",
    ),
  ],
)
```

### Android Compose Implementation
```kotlin
@Composable
fun DCFTopAppBar(navController: NavHostController, pushConfig: Map<String, Any>?) {
    TopAppBar(
        title = { Text(pushConfig?.get("title") as? String ?: "") },
        navigationIcon = {
            // Back button (unless hideBackButton = true)
            if (navController.previousBackStackEntry != null && 
                pushConfig?.get("hideBackButton") != true) {
                IconButton(onClick = { navController.popBackStack() }) {
                    Icon(Icons.Default.ArrowBack, "Back")
                }
            }
            
            // Prefix actions (left side)
            (pushConfig?.get("prefixActions") as? List<Map<String, Any>>)?.forEach { action ->
                HeaderActionButton(action, onPress = { actionId ->
                    fireHeaderActionEvent(route, actionId)
                })
            }
        },
        actions = {
            // Suffix actions (right side)
            (pushConfig?.get("suffixActions") as? List<Map<String, Any>>)?.forEach { action ->
                HeaderActionButton(action, onPress = { actionId ->
                    fireHeaderActionEvent(route, actionId)
                })
            }
        }
    )
}

@Composable
fun HeaderActionButton(action: Map<String, Any>, onPress: (String) -> Unit) {
    IconButton(onClick = { onPress(action["actionId"] as? String ?: "") }) {
        // Render icon based on type (SF Symbol -> Material Icon, SVG -> custom)
        val iconConfig = action["icon"] as? Map<String, Any>
        when (iconConfig?.get("type")) {
            "sf" -> {
                // Map SF Symbol to Material Icon
                val symbolName = iconConfig["name"] as? String
                val materialIcon = mapSFSymbolToMaterialIcon(symbolName)
                Icon(materialIcon, action["title"] as? String ?: "")
            }
            "svg" -> {
                // Load SVG from assets
                val assetPath = iconConfig["assetPath"] as? String
                // Use coil-svg or similar to load SVG
            }
        }
    }
}
```

---

## 🔄 Lifecycle Event Flow

### iOS Flow
```
Screen Registration
  ↓
ScreenContainer created
  ↓
Stored in routeRegistry
  ↓
Navigation Command
  ↓
pushViewController called
  ↓
onAppear event fired
  ↓
Screen visible
  ↓
Back button pressed
  ↓
popViewController called
  ↓
onDisappear event fired
```

### Android Flow (Should Match)
```
Screen Registration (DCFScreen createView)
  ↓
ScreenContainer created
  ↓
Stored in DCFScreenRegistry
  ↓
Navigation Command
  ↓
navController.navigate() called
  ↓
Composable enters composition (DisposableEffect)
  ↓
onAppear event fired
  ↓
Screen visible
  ↓
Back button pressed
  ↓
navController.popBackStack() called
  ↓
Composable leaves composition (onDispose)
  ↓
onDisappear event fired
```

---

## 🚀 Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Create `ScreenContainer` data class
- [ ] Implement `DCFScreenRegistry` singleton
- [ ] Setup Compose dependencies in `build.gradle`
- [ ] Create `DCFStackNavigationBootstrapperComponent`
- [ ] Implement `DCFScreenComponent.createView()` for registration

### Phase 2: Navigation Methods
- [ ] Implement `navigateToRoute()`
- [ ] Implement `popCurrentRoute()`
- [ ] Implement `popToRoute()`
- [ ] Implement `popToRoot()`
- [ ] Implement `replaceCurrentRoute()`

### Phase 3: TopAppBar
- [ ] Create `DCFTopAppBar` composable
- [ ] Implement title configuration
- [ ] Implement back button (navigationIcon)
- [ ] Implement prefix actions (left side)
- [ ] Implement suffix actions (right side)
- [ ] Map SF Symbols to Material Icons

### Phase 4: Lifecycle Events
- [ ] Fire `onAppear` when screen enters composition
- [ ] Fire `onDisappear` when screen leaves composition
- [ ] Fire `onReceiveParams` when navigating with params
- [ ] Fire `onHeaderActionPress` when action button pressed
- [ ] Fire `onNavigationEvent` for navigation changes

### Phase 5: Modal & Sheet Support (Later)
- [ ] Implement modal presentation with `Dialog`
- [ ] Implement sheet presentation with `ModalBottomSheet`
- [ ] Handle modal dismissal

---

## 🎯 Key Differences iOS vs Android

| Aspect | iOS | Android |
|--------|-----|---------|
| **Navigation Container** | UINavigationController | NavHostController + NavHost |
| **Screen Type** | UIViewController | @Composable function |
| **View System** | UIKit (imperative) | Jetpack Compose (declarative) |
| **TopBar** | navigationItem | TopAppBar composable |
| **Lifecycle** | viewWillAppear/viewDidDisappear | DisposableEffect with onDispose |
| **Back Button** | Built-in to UINavigationController | BackHandler + TopAppBar navigationIcon |
| **Animation** | UIView animations | Compose animations |
| **Modal** | present(modalVC, animated: true) | Dialog or ModalBottomSheet |

---

## 📝 Critical Implementation Notes

### 1. View Integration Challenge

**iOS**: DCFlight renders to `UIView`, which is easy to wrap in `UIViewController`

**Android**: DCFlight renders to Android `View`, which needs to be wrapped in `AndroidView` composable:

```kotlin
@Composable
fun DCFScreenContent(route: String) {
    val screenContainer = DCFScreenRegistry.getScreen(route)
    val dcflightView = screenContainer?.composeView  // This is the Android View from DCFlight VDOM
    
    AndroidView(
        factory = { dcflightView ?: View(it) },
        modifier = Modifier.fillMaxSize()
    )
}
```

### 2. Registration Timing

**Challenge**: Screens must be registered BEFORE navigation happens

**Solution**: Use retry logic (like iOS) in bootstrapper:
```kotlin
private fun setupInitialScreenWithRetry(initialScreen: String, retryCount: Int, maxRetries: Int) {
    if (DCFScreenRegistry.getScreen(initialScreen) != null) {
        // Screen found, proceed
        return
    }
    
    if (retryCount < maxRetries) {
        Handler(Looper.getMainLooper()).postDelayed({
            setupInitialScreenWithRetry(initialScreen, retryCount + 1, maxRetries)
        }, 50 * (retryCount + 1))  // Exponential backoff
    } else {
        // Show fallback screen
    }
}
```

### 3. Lifecycle Event Propagation

**iOS**: Uses `propagateEvent()` helper function

**Android**: Must call same function but with Android View:
```kotlin
fun fireLifecycleEvent(screenContainer: ScreenContainer, eventName: String, data: Map<String, Any>) {
    screenContainer.composeView?.let { androidView ->
        propagateEvent(
            on = androidView,  // Android View from DCFlight
            eventName = eventName,
            data = data
        )
    }
}
```

### 4. SF Symbol to Material Icon Mapping

**iOS**: Uses SF Symbols (e.g., "magnifyingglass", "plus")

**Android**: Must map to Material Icons:
```kotlin
fun mapSFSymbolToMaterialIcon(symbolName: String?): ImageVector {
    return when (symbolName) {
        "magnifyingglass" -> Icons.Default.Search
        "plus" -> Icons.Default.Add
        "person" -> Icons.Default.Person
        "gear" -> Icons.Default.Settings
        "heart" -> Icons.Default.Favorite
        // ... more mappings
        else -> Icons.Default.Info  // Fallback
    }
}
```

---

## 🎓 Summary

### What You Have (iOS)
✅ UINavigationController-based stack navigation  
✅ Declarative screen registration via DCFScreen  
✅ Route-based navigation API (AppNavigation)  
✅ Rich TopAppBar configuration (title, buttons)  
✅ Lifecycle events (onAppear, onDisappear, etc.)  
✅ Navigation commands (push, pop, replace, modal)  
✅ Retry logic for screen registration  
✅ Global registry pattern  

### What You Need (Android)
🎯 NavController + NavHost-based stack navigation  
🎯 Same declarative screen registration  
🎯 Same route-based navigation API  
🎯 TopAppBar composable with same config  
🎯 Same lifecycle events via Compose  
🎯 Same navigation commands  
🎯 Same retry logic  
🎯 Same global registry pattern  

### The Path Forward
1. **Start with ScreenContainer + Registry** - Core data structures
2. **Build Bootstrapper** - NavHost setup
3. **Implement Navigation Methods** - 1:1 with iOS
4. **Add TopAppBar** - Match iOS navigation bar
5. **Wire Lifecycle Events** - Fire same events as iOS
6. **Test with Example App** - Your dcf_go template

---

**Status**: Ready for Android implementation 🚀  
**Complexity**: Medium - mostly 1:1 translation from iOS patterns  
**Timeline**: 3-5 days for full stack navigation parity

