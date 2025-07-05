# DCFlight Hooks Guide for Flutter Developers

Welcome to DCFlight! If you're coming from Flutter, this guide will help you understand how to use hooks in DCFlight and when to use each one. Think of hooks as Flutter's lifecycle methods but more powerful and flexible.

## 🚀 Quick Start: Flutter vs DCFlight Concepts

| Flutter Concept | DCFlight Equivalent | Description |
|----------------|-------------------|-------------|
| `setState()` | `useState()` | Manage local component state |
| `initState()` | `useEffect(() => {}, [])` | Run code when component mounts |
| `dispose()` | `useEffect(() => cleanup, [])` | Run cleanup when component unmounts |
| `didUpdateWidget()` | `useEffect(() => {}, [dependency])` | Run code when specific values change |
| `GlobalKey` | `useRef()` | Store references to values/objects |
| `Provider/Consumer` | `useStore()` | Access global state |

## 📚 All DCFlight Hooks

### 1. `useState<T>()` - Local Component State

**What it does:** Manages local state in your component, like Flutter's `setState()`.

**Flutter equivalent:** `StatefulWidget` with `setState()`

```dart
// Flutter way
class Counter extends StatefulWidget {
  @override
  _CounterState createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int count = 0;
  
  void increment() {
    setState(() {
      count++;
    });
  }
}

// DCFlight way
class Counter extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    
    return DCFButton(
      buttonProps: DCFButtonProps(title: "Count: ${count.state}"),
      onPress: (v) {
        count.setState(count.state + 1);
      },
    );
  }
}
```

**When to use:**
- Managing form inputs
- Toggle states (visible/hidden)
- Counters, timers
- Any data that changes within the component

### 2. `useEffect()` - Side Effects (Immediate)

**What it does:** Runs side effects immediately after the component mounts or updates.

**Flutter equivalent:** `initState()`, `didUpdateWidget()`, `dispose()`

```dart
// Flutter way
class DataWidget extends StatefulWidget {
  @override
  _DataWidgetState createState() => _DataWidgetState();
}

class _DataWidgetState extends State<DataWidget> {
  String? data;
  
  @override
  void initState() {
    super.initState();
    fetchData();
  }
  
  void fetchData() async {
    final result = await api.getData();
    setState(() {
      data = result;
    });
  }
}

// DCFlight way
class DataWidget extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final data = useState<String?>(null);
    
    // Runs immediately when component mounts
    useEffect(() {
      fetchData().then((result) {
        data.setState(result);
      });
      return null; // No cleanup needed
    }, dependencies: []); // Empty array = run once on mount
    
    return DCFText(content: data.state ?? "Loading...");
  }
}
```

**When to use:**
- API calls
- Setting up subscriptions
- Starting timers
- Any immediate side effect

**Dependencies explained:**
```dart
// Run once when component mounts
useEffect(() => {}, dependencies: []);

// Run every time component re-renders
useEffect(() => {}, dependencies: null);

// Run when specific values change
useEffect(() => {}, dependencies: [someValue, anotherValue]);
```

### 3. `useLayoutEffect()` - After Children Mount

**What it does:** Runs after the component AND its children are mounted. Perfect for operations that need the full component subtree.

**Flutter equivalent:** No direct equivalent - similar to `WidgetsBinding.instance.addPostFrameCallback()`

```dart
class ParentWidget extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final childRef = useRef<String?>(null);
    
    // Runs after this component AND all children are mounted
    useLayoutEffect(() {
      print("All children are now ready!");
      // Safe to interact with child components here
      return null;
    }, dependencies: []);
    
    return DCFView(
      children: [
        ChildWidget(),
        AnotherChildWidget(),
      ],
    );
  }
}
```

**When to use:**
- Measuring component sizes
- Setting up component interactions
- Operations that need child components to be ready
- Focus management

### 4. `useInsertionEffect()` - After Entire Tree Ready

**What it does:** Runs after the ENTIRE component tree is ready. Perfect for operations that need the full app to be initialized.

**Flutter equivalent:** No direct equivalent - similar to `WidgetsBinding.instance.addPostFrameCallback()` but for the entire app

```dart
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final overlayCommand = useStore(publicOverlayLoadingCommand);
    
    // ✅ PERFECT for navigation that needs screens to be registered
    useInsertionEffect(() {
      overlayCommand.setState(
        ScreenNavigationCommand(
          presentOverlay: PresentOverlayCommand(screenName: "overlay_loading")
        )
      );
      return null;
    }, dependencies: []);
    
    return DCFView(
      children: [
        HomeScreen(),
        ProfileScreen(),
        SettingsScreen(),
      ],
    );
  }
}
```

**When to use:**
- Navigation commands that reference other screens
- Global app initialization
- Third-party library setup that needs full DOM
- Analytics setup

### 5. `useRef<T>()` - Persistent References

**What it does:** Stores a mutable reference that persists across re-renders.

**Flutter equivalent:** Instance variables in StatefulWidget

```dart
// Flutter way
class TimerWidget extends StatefulWidget {
  @override
  _TimerWidgetState createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  Timer? timer; // Instance variable
  
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}

// DCFlight way
class TimerWidget extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final timer = useRef<Timer?>(null);
    final count = useState<int>(0);
    
    useEffect(() {
      timer.current = Timer.periodic(Duration(seconds: 1), (t) {
        count.setState(count.state + 1);
      });
      
      // Cleanup
      return () {
        timer.current?.cancel();
      };
    }, dependencies: []);
    
    return DCFText(content: "Time: ${count.state}");
  }
}
```

**When to use:**
- Storing timers, subscriptions
- Caching expensive calculations
- Storing previous values
- Any mutable reference that shouldn't trigger re-renders

### 6. `useStore<T>()` - Global State

**What it does:** Connects to global state management, automatically re-rendering when state changes.

**Flutter equivalent:** `Provider.of<T>(context)` or `BlocBuilder`

```dart
// Global state
final counterStore = Store<int>(0);

// Flutter way with Provider
class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = Provider.of<int>(context);
    
    return Text('Count: $count');
  }
}

// DCFlight way
class CounterWidget extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useStore(counterStore);
    
    return DCFText(content: "Count: ${counter.state}");
  }
}
```

**When to use:**
- User authentication state
- Theme/settings
- Shopping cart data
- Any data shared between components

### 7. `useMemo<T>()` - Expensive Calculations

**What it does:** Caches expensive calculations, only recalculating when dependencies change.

**Flutter equivalent:** No direct equivalent - similar to computed properties

```dart
class ExpensiveWidget extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final items = useStore(itemsStore);
    final searchTerm = useState<String>("");
    
    // Only recalculate when items or searchTerm changes
    final filteredItems = useMemo<List<Item>>(() {
      print("Expensive filtering happening...");
      return items.state.where((item) => 
        item.name.contains(searchTerm.state)
      ).toList();
    }, dependencies: [items.state, searchTerm.state]);
    
    return DCFView(
      children: [
        DCFTextInput(
          onTextChange: (v) => searchTerm.setState(v['text']),
        ),
        ...filteredItems.map((item) => ItemWidget(item: item)),
      ],
    );
  }
}
```

**When to use:**
- Expensive filtering/sorting
- Complex calculations
- Creating child component instances
- Any computation that's expensive to repeat

## 🎯 Choosing the Right Hook

### **For State Management:**
- Local state → `useState()`
- Global state → `useStore()`
- Mutable references → `useRef()`

### **For Side Effects:**
- API calls, timers → `useEffect()`
- Child component interactions → `useLayoutEffect()`
- Navigation, global setup → `useInsertionEffect()`

### **For Performance:**
- Expensive calculations → `useMemo()`

## ⚡ Common Patterns

### 1. API Data Fetching
```dart
class UserProfile extends StatefulComponent {
  final String userId;
  
  UserProfile({required this.userId});
  
  @override
  DCFComponentNode render() {
    final user = useState<User?>(null);
    final loading = useState<bool>(true);
    
    useEffect(() {
      // Fetch user when component mounts or userId changes
      fetchUser(userId).then((userData) {
        user.setState(userData);
        loading.setState(false);
      });
      return null;
    }, dependencies: [userId]);
    
    if (loading.state) {
      return DCFSpinner();
    }
    
    return DCFText(content: "Hello ${user.state?.name}");
  }
}
```

### 2. Form Handling
```dart
class LoginForm extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final email = useState<String>("");
    final password = useState<String>("");
    final authStore = useStore(globalAuthStore);
    
    void handleSubmit() {
      authStore.setState({
        'email': email.state,
        'password': password.state,
      });
    }
    
    return DCFView(
      children: [
        DCFTextInput(
          placeholder: "Email",
          onTextChange: (v) => email.setState(v['text']),
        ),
        DCFTextInput(
          placeholder: "Password",
          isSecure: true,
          onTextChange: (v) => password.setState(v['text']),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Login"),
          onPress: (v) => handleSubmit(),
        ),
      ],
    );
  }
}
```

### 3. Navigation with Proper Timing
```dart
class NavigationExample extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final overlayCommand = useStore(publicOverlayLoadingCommand);
    
    // ✅ Use useInsertionEffect for navigation
    useInsertionEffect(() {
      // This runs after all screens are registered
      overlayCommand.setState(
        ScreenNavigationCommand(
          presentOverlay: PresentOverlayCommand(screenName: "welcome_overlay")
        )
      );
      return null;
    }, dependencies: []);
    
    return DCFView(
      children: [
        HomeTab(),
        ProfileTab(),
        SettingsTab(),
      ],
    );
  }
}
```

## 🚨 Common Mistakes to Avoid

### 1. ❌ Wrong Hook for Navigation
```dart
// ❌ DON'T do this - causes timing issues
useEffect(() {
  overlayCommand.setState(/* navigation command */);
}, dependencies: []);

// ✅ DO this instead
useInsertionEffect(() {
  overlayCommand.setState(/* navigation command */);
}, dependencies: []);
```

### 2. ❌ Missing Dependencies
```dart
// ❌ DON'T do this - effect won't re-run when userId changes
useEffect(() {
  fetchUser(userId);
}, dependencies: []); // Missing userId!

// ✅ DO this instead
useEffect(() {
  fetchUser(userId);
}, dependencies: [userId]); // Include userId
```

### 3. ❌ Not Cleaning Up
```dart
// ❌ DON'T do this - timer will leak
useEffect(() {
  Timer.periodic(Duration(seconds: 1), (timer) {
    // Do something
  });
  return null; // No cleanup!
}, dependencies: []);

// ✅ DO this instead
useEffect(() {
  final timer = Timer.periodic(Duration(seconds: 1), (timer) {
    // Do something
  });
  
  return () {
    timer.cancel(); // Cleanup!
  };
}, dependencies: []);
```

## 🎉 Migration Tips from Flutter

1. **State Management:** Replace `setState()` calls with `useState()` hooks
2. **Lifecycle Methods:** Replace `initState()` with `useEffect(() => {}, [])`
3. **Global State:** Replace Provider/Bloc with `useStore()`
4. **Navigation:** Use `useInsertionEffect()` for navigation commands
5. **Performance:** Use `useMemo()` instead of rebuilding expensive widgets

Welcome to DCFlight! Hooks make your code more predictable and easier to reason about than traditional lifecycle methods. 🚀