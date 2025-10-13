# DCFlight CLI Quick Reference

## 🚀 Installation
```bash
dart pub global activate dcflight_cli
```

## 📋 Commands

### `dcf go` - Run App
```bash
dcf go                    # Start with hot reload
dcf go --verbose          # Verbose output
dcf go --no-hot-reload    # Disable hot reload
dcf go --dcf-args="--debug"  # Pass Flutter args
```

### `dcf create` - Create Projects
```bash
dcf create app my_app     # Create new DCFlight app
dcf create module my_mod  # Create new DCFlight module
```

### `dcf inject` - Add Packages
```bash
dcf inject http           # Add http package
dcf inject dio --version ^5.0.0  # Add with version
dcf inject lints --dev    # Add as dev dependency
dcf inject package --verbose  # Verbose output
```

### `dcf eject` - Remove Packages
```bash
dcf eject http            # Remove http package
dcf eject lints --dev    # Remove from dev deps
dcf eject package --force  # Force removal
dcf eject package --verbose  # Verbose output
```

## 🔧 Common Workflows

### New Project
```bash
dcf create app my_app
cd my_app
dcf go
```

### Add Dependencies
```bash
dcf inject dio
dcf inject http
dcf inject lints --dev
```

### Development
```bash
dcf go --verbose  # Start with logging
# Make changes to code
# Hot reload happens automatically
```

### Clean Up
```bash
dcf eject unused_package
dcf eject old_dependency --force
```

## 📊 Analytics
- Package usage logged to `.dcflight/analytics/package_usage.json`
- Future framework improvements based on usage data
- Framework-specific package recommendations

## 🆘 Help
```bash
dcf --help              # Show all commands
dcf go --help           # Show go command options
dcf inject --help       # Show inject command options
dcf eject --help        # Show eject command options
dcf create --help       # Show create command options
```

## 🔗 Related
- [Full CLI Guide](./CLI_GUIDE.md) - Complete documentation
- [Getting Started](./GETTING_STARTED.md) - Setup tutorial
- [Troubleshooting](./TROUBLESHOOTING.md) - Common issues
