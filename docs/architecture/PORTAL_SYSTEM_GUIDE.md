# DCFlight Portal System Guide

> **Complete guide to understanding and using DCFlight's React-like portal system**

## 🎯 **What Are Portals?**

Portals provide a way to render children into a DOM node that exists outside the parent component's hierarchy. This is essential for:

- **Modals and Overlays**: Render above all other content
- **Tooltips**: Position relative to different parts of the screen
- **Notifications**: Show at app level from deep components
- **Floating Elements**: Break out of container constraints

## 🏗️ **Portal Architecture**

### Core Components

```dart
// 1. Portal Target - Where content will be rendered
DCFPortalTarget(targetId: "unique-target-id")

// 2. Portal - What content to render
DCFPortal(
  targetId: "unique-target-id",
  children: [/* your content */],
)
```

### How It Works Under the Hood

```
┌─ App Component Tree ─────────────────┐
│  DCFSafeAreaView                     │
│  ├── Navigation                      │
│  ├── DCFPortalTarget(id: "modal")    │ ← Target at app level
│  └── Page                            │
│      └── DeepComponent               │
│          └── DCFPortal(id: "modal")  │ ← Portal from deep component
│              └── Modal Content       │   (renders at target ↑)
└──────────────────────────────────────┘
```

## ⚠️ **Critical Rule: One Portal Per Target**

### ❌ WRONG - Multiple Portals Competing

```dart
class BadPortalExample extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final showModal = useState<bool>(false);
    
    return DCFView(
      children: [
        // ❌ PROBLEM: Two portals targeting same ID
        if (showModal.state)
          DCFPortal(targetId: "modal", children: [ModalA()]),
        
        DCFPortal(targetId: "modal", children: [ModalB()]), // Conflict!
        
        DCFPortalTarget(targetId: "modal"),
      ],
    );
  }
}
```

**Result**: VDOM reconciliation conflicts, unpredictable rendering, content jumping.

### ✅ CORRECT - Single Portal with Conditional Content

```dart
class GoodPortalExample extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final showModal = useState<bool>(false);
    
    return DCFView(
      children: [
        // ✅ SOLUTION: One portal, conditional children
        DCFPortal(
          targetId: "modal",
          children: [
            if (showModal.state) ModalA(),
          ],
        ),
        
        DCFPortalTarget(targetId: "modal"),
      ],
    );
  }
}
```

## 🎨 **Best Practices & Patterns**

### 1. Global Portal Targets

Place portal targets at the app level for maximum flexibility:

```dart
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFSafeAreaView(
      children: [
        // App navigation
        NavigationBar(),
        
        // 🎯 Global portal targets
        DCFPortalTarget(targetId: "modal"),      // For modals
        DCFPortalTarget(targetId: "toast"),      // For notifications
        DCFPortalTarget(targetId: "tooltip"),    // For tooltips
        
        // Main content area
        DCFView(
          layout: LayoutProps(flex: 1),
          children: [
            // Your app pages can portal to targets above
            CurrentPage(),
          ],
        ),
      ],
    );
  }
}
```

### 2. Conditional Content, Not Conditional Portals

```dart
// ✅ GOOD: Always render portal, conditionally render content
DCFPortal(
  targetId: "notification",
  children: [
    if (hasNotification.state)
      DCFText(content: notification.state.message),
  ],
)

// ❌ BAD: Conditionally render entire portal
if (hasNotification.state)
  DCFPortal(
    targetId: "notification", 
    children: [DCFText(content: notification.state.message)],
  )
```

### 3. Multiple Content Types in One Portal

```dart
DCFPortal(
  targetId: "overlay",
  children: [
    // Multiple conditional elements
    if (showModal.state) ModalComponent(),
    if (showTooltip.state) TooltipComponent(),
    if (showDropdown.state) DropdownComponent(),
  ],
)
```

### 4. Portal State Management

```dart
class PortalManager extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final modalType = useStore(modalStore);
    final toastQueue = useStore(toastStore);
    
    return DCFFragment(
      children: [
        // Modal portal
        DCFPortal(
          targetId: "modal",
          children: [
            if (modalType.state == "confirm") ConfirmModal(),
            if (modalType.state == "alert") AlertModal(),
            if (modalType.state == "custom") CustomModal(),
          ],
        ),
        
        // Toast portal
        DCFPortal(
          targetId: "toast",
          children: toastQueue.state.map((toast) => 
            ToastComponent(message: toast.message, type: toast.type)
          ).toList(),
        ),
      ],
    );
  }
}
```

## 🔄 **VDOM Reconciliation & Portals**

### How VDOM Handles Portals

1. **Portal Registration**: When a portal mounts, it registers with the portal manager
2. **Target Mapping**: Portal manager maps portal content to native view IDs
3. **Content Rendering**: Portal children render into target's native container
4. **Reconciliation**: VDOM reconciles portal content like normal components
5. **Cleanup**: When portal unmounts, content is removed from target

### Reconciliation Example

```dart
// Initial render
DCFPortal(targetId: "modal", children: [])  // Empty portal

// State change - add content
DCFPortal(targetId: "modal", children: [
  DCFText(content: "Hello Portal!"),
])  // VDOM adds text to target

// State change - modify content  
DCFPortal(targetId: "modal", children: [
  DCFText(content: "Updated Portal!"),
])  // VDOM updates existing text

// State change - remove content
DCFPortal(targetId: "modal", children: [])  // VDOM removes text from target
```

### Why Multiple Portals Cause Issues

```dart
// Frame 1: Both portals render
Portal1(targetId: "shared", children: [TextA()])  // Renders TextA
Portal2(targetId: "shared", children: [TextB()])  // Overwrites with TextB

// Frame 2: Portal1 updates
Portal1(targetId: "shared", children: [TextC()])  // Tries to update TextA → TextC
Portal2(targetId: "shared", children: [TextB()])  // Still thinks it owns TextB

// Result: VDOM confusion, content jumping, memory leaks
```

## 🛠️ **Advanced Portal Patterns**

### 1. Portal with Animation

```dart
class AnimatedPortal extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final isVisible = useState<bool>(false);
    final animationValue = useState<double>(0.0);
    
    // Animate opacity when visibility changes
    useEffect(() {
      if (isVisible.state) {
        animationValue.setState(1.0);
      } else {
        animationValue.setState(0.0);
      }
    }, [isVisible.state]);
    
    return DCFPortal(
      targetId: "animated-overlay",
      children: [
        if (isVisible.state)
          DCFAnimatedView(
            toOpacity: animationValue.state,
            children: [ModalContent()],
          ),
      ],
    );
  }
}
```

### 2. Portal with Context

```dart
class ContextualPortal extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useContext(ThemeContext);
    final user = useContext(UserContext);
    
    return DCFPortal(
      targetId: "contextual",
      children: [
        if (shouldShowContent())
          DCFView(
            styleSheet: StyleSheet(
              backgroundColor: theme.backgroundColor,
            ),
            children: [
              DCFText(content: "Hello ${user.name}!"),
            ],
          ),
      ],
    );
  }
}
```

### 3. Nested Portal Targets

```dart
class NestedPortalApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      children: [
        // App-level portal target
        DCFPortalTarget(targetId: "app-modal"),
        
        // Page content with its own portal target
        DCFView(
          children: [
            DCFPortalTarget(targetId: "page-tooltip"),
            PageContent(),
          ],
        ),
      ],
    );
  }
}
```

## 🚨 **Common Pitfalls & Solutions**

### Pitfall 1: Portal ID Conflicts

```dart
// ❌ PROBLEM: Same ID used in different components
class ComponentA {
  DCFPortal(targetId: "popup", ...)  // Conflicts with ComponentB
}

class ComponentB {  
  DCFPortal(targetId: "popup", ...)  // Conflicts with ComponentA
}

// ✅ SOLUTION: Unique IDs or coordinate at app level
class ComponentA {
  DCFPortal(targetId: "component-a-popup", ...)
}

class ComponentB {
  DCFPortal(targetId: "component-b-popup", ...)
}
```

### Pitfall 2: Missing Portal Targets

```dart
// ❌ PROBLEM: Portal without target
DCFPortal(targetId: "missing-target", children: [...])

// ✅ SOLUTION: Ensure target exists
DCFPortalTarget(targetId: "missing-target")  // Add this first
DCFPortal(targetId: "missing-target", children: [...])
```

### Pitfall 3: Conditional Portal Mounting

```dart
// ❌ PROBLEM: Portal appears/disappears causes reconciliation issues
if (someCondition)
  DCFPortal(targetId: "conditional", children: [...])

// ✅ SOLUTION: Keep portal, conditionally render children
DCFPortal(
  targetId: "conditional",
  children: [
    if (someCondition) ...yourContent,
  ],
)
```

## 📋 **Portal Checklist**

Before implementing portals, ensure:

- [ ] ✅ Portal target exists before portal renders
- [ ] ✅ Only one portal per target ID
- [ ] ✅ Use conditional children, not conditional portals
- [ ] ✅ Unique target IDs across your app
- [ ] ✅ Portal targets placed at appropriate hierarchy level
- [ ] ✅ Proper cleanup when components unmount
- [ ] ✅ Consider z-index/layering for overlapping content

## 🎯 **Portal System Summary**

| Concept | Description | Example |
|---------|-------------|---------|
| **Portal Target** | Where content renders | `DCFPortalTarget(targetId: "modal")` |
| **Portal** | What content to render | `DCFPortal(targetId: "modal", children: [...])` |
| **Target ID** | Unique identifier linking portal to target | `"modal"`, `"toast"`, `"tooltip"` |
| **Conditional Content** | Show/hide content within portal | `if (show) ModalComponent()` |
| **Global Targets** | App-level targets for maximum reach | Place in root `DCFSafeAreaView` |

## 🔗 **Related Documentation**

- [VDOM Architecture](VDOM_ARCHITECTURE.md)
- [Component Lifecycle](EVENT_LIFECYCLE_AND_CALLBACKS.md)
- [State Management](../module_dev_guidelines/COMPONENT_DEVELOPMENT_GUIDELINES.md)

---

**Remember**: Portals are about **where** content renders, not **when**. Use conditional children to control **when** content appears within a consistently placed portal.
