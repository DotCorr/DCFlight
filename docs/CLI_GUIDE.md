# DCFlight CLI Guide

The DCFlight CLI is your primary tool for managing DCFlight projects, packages, and development workflow. This guide covers all available commands and their usage.

## 🚀 Installation

```bash
# Install the DCFlight CLI globally
dart pub global activate dcflight_cli

# Verify installation
dcf --help
```

## 📋 Available Commands

### `dcf go` - Run DCFlight App
Start your DCFlight application with hot reload enabled by default.

```bash
# Basic usage
dcf go

# With verbose output
dcf go --verbose

# Disable hot reload
dcf go --no-hot-reload

# Pass additional arguments to Flutter
dcf go --dcf-args="--debug,--verbose"
```

**Options:**
- `-v, --verbose` - Enable verbose output
- `--no-hot-reload` - Disable hot reload watcher
- `--dcf-args` - Additional Flutter run arguments

### `dcf create` - Create Projects and Modules
Create new DCFlight projects or modules.

#### Create New App
```bash
# Create a new DCFlight app
dcf create app my_awesome_app

# The CLI will prompt for:
# - Project name
# - App name  
# - Package name
# - Target platforms (iOS, Android, Web, etc.)
# - Description
# - Organization
```

#### Create New Module
```bash
# Create a new DCFlight module
dcf create module my_custom_module

# The CLI will prompt for:
# - Module name
# - Module description
```

### `dcf inject` - Add Packages
Add packages to your DCFlight project with intelligent dependency management.

```bash
# Add a regular dependency
dcf inject http

# Add with specific version
dcf inject dio --version ^5.0.0

# Add as dev dependency
dcf inject lints --dev

# Add with verbose output
dcf inject package_name --verbose
```

**Options:**
- `-d, --dev` - Add as dev dependency
- `-v, --verbose` - Verbose output
- `--version` - Specify package version

**Examples:**
```bash
# Common packages
dcf inject http
dcf inject dio
dcf inject provider

# Development tools
dcf inject lints --dev
dcf inject test --dev

# With specific versions
dcf inject http --version ^1.0.0
dcf inject dio --version ^5.0.0 --verbose
```

### `dcf eject` - Remove Packages
Remove packages from your DCFlight project.

```bash
# Remove a package
dcf eject http

# Remove from dev dependencies
dcf eject lints --dev

# Force removal without confirmation
dcf eject package_name --force

# Remove with verbose output
dcf eject package_name --verbose
```

**Options:**
- `-d, --dev` - Remove from dev dependencies
- `-v, --verbose` - Verbose output
- `-f, --force` - Force removal without confirmation

**Examples:**
```bash
# Remove regular dependencies
dcf eject http
dcf eject dio

# Remove dev dependencies
dcf eject lints --dev
dcf eject test --dev

# Force removal
dcf eject unused_package --force
```

## 🔧 Development Workflow

### 1. Create a New Project
```bash
# Create new DCFlight app
dcf create app my_app
cd my_app

# Start development
dcf go
```

### 2. Add Dependencies
```bash
# Add HTTP client
dcf inject dio

# Add state management
dcf inject provider

# Add development tools
dcf inject lints --dev
```

### 3. Development with Hot Reload
```bash
# Start with hot reload (default)
dcf go

# Start without hot reload
dcf go --no-hot-reload

# Start with verbose logging
dcf go --verbose
```

### 4. Package Management
```bash
# Add new packages as needed
dcf inject package_name

# Remove unused packages
dcf eject package_name

# Check what's installed
cat pubspec.yaml
```

## 📊 Analytics and Future-Proofing

The DCFlight CLI includes built-in analytics to help improve the framework:

### Analytics Data
All package operations are logged to `.dcflight/analytics/package_usage.json`:
```json
{
  "timestamp": "2024-01-15T10:30:00.000Z",
  "action": "inject",
  "package": "dio",
  "isDev": false,
  "version": "^5.0.0",
  "framework": "dcflight"
}
```

### Benefits
- **Framework Insights** - Understand which packages are most popular
- **Future Recommendations** - Get package suggestions based on usage patterns
- **Framework-Specific Libraries** - Prepare for DCFlight-specific packages
- **Performance Optimization** - Identify commonly used package combinations

## 🎯 Best Practices

### Project Structure
```
my_dcflight_app/
├── lib/
│   ├── main.dart
│   ├── components/
│   └── screens/
├── assets/
├── .dcflight/
│   └── analytics/
│       └── package_usage.json
└── pubspec.yaml
```

### Package Management
```bash
# Add packages as you need them
dcf inject http
dcf inject dio

# Keep dev dependencies separate
dcf inject lints --dev
dcf inject test --dev

# Remove unused packages regularly
dcf eject unused_package
```

### Development Workflow
```bash
# 1. Create project
dcf create app my_app
cd my_app

# 2. Add dependencies
dcf inject dio
dcf inject provider

# 3. Start development
dcf go

# 4. Add more packages as needed
dcf inject http
dcf inject image_picker

# 5. Remove unused packages
dcf eject unused_package
```

## 🐛 Troubleshooting

### Common Issues

#### Command Not Found
```bash
# Reinstall CLI
dart pub global deactivate dcflight_cli
dart pub global activate dcflight_cli
```

#### Package Injection Fails
```bash
# Check if package exists
flutter pub deps

# Try with verbose output
dcf inject package_name --verbose
```

#### Hot Reload Issues
```bash
# Disable hot reload
dcf go --no-hot-reload

# Or restart with verbose output
dcf go --verbose
```

### Debug Information
```bash
# Get detailed output for any command
dcf go --verbose
dcf inject package --verbose
dcf eject package --verbose
```

## 🔮 Future Features

The DCFlight CLI is designed to be future-proof and will include:

- **Framework-Specific Packages** - DCFlight-optimized packages
- **Smart Recommendations** - AI-powered package suggestions
- **Performance Analytics** - Package performance impact analysis
- **Migration Tools** - Easy upgrades between DCFlight versions
- **Template System** - Custom project templates
- **Plugin Ecosystem** - Third-party CLI extensions

## 📚 Related Documentation

- [Getting Started Guide](./GETTING_STARTED.md) - Complete setup tutorial
- [Architecture Overview](./ARCHITECTURE.md) - Framework internals
- [Component System](./engine/components/components.md) - Building components
- [Troubleshooting Guide](./TROUBLESHOOTING.md) - Common issues and solutions

---

**Need Help?** Check the [Troubleshooting Guide](./TROUBLESHOOTING.md) or create an issue on [GitHub](https://github.com/DotCorr/DCFlight/issues).
