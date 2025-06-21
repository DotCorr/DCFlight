# DCFlight Primitives Documentation Index

📚 **Complete guide to DCFlight primitive components and development**

## 📖 Documentation Structure

### 🚀 Getting Started
- **[Main Primitives Guide](./README.md)** - Overview of all available primitives and their purposes
- **[API Reference](./API_REFERENCE.md)** - Detailed API documentation for each component
- **[Migration Guide](./MIGRATION_GUIDE.md)** - Upgrading from previous versions

### 🛠️ Development Resources
- **[Component Development Guidelines](../module_dev_guidelines/COMPONENT_DEVELOPMENT_GUIDELINES.md)** - How to create new primitives
- **[Component Development Roadmap](../module_dev_guidelines/COMPONENT_DEVELOPMENT_ROADMAP.md)** - Framework development roadmap
- **[Presentable Components Guide](../module_dev_guidelines/PRESENTABLE_COMPONENTS_GUIDE.md)** - UI component best practices

## 🎯 Quick Navigation

### By Use Case
- **Layout**: DCFView, DCFModal, DCFVirtualizedFlatList, DCFVirtualizedScrollView
- **Input**: DCFTextInput, DCFButton, DCFToggle, DCFCheckbox, DCFSlider, DCFSegmentedControl, DCFDropdown
- **Display**: DCFText, DCFImage, DCFSvg, DCFIcon, DCFSpinner
- **Interaction**: DCFTouchableOpacity, DCFGestureDetector, DCFAnimatedView, DCFAlert

### By Complexity
- **Basic**: DCFView, DCFText, DCFButton, DCFImage
- **Intermediate**: DCFTextInput, DCFToggle, DCFCheckbox, DCFSlider
- **Advanced**: DCFModal, DCFVirtualizedFlatList, DCFSegmentedControl, DCFGestureDetector

## 🆕 What's New in v0.0.2

### ✅ Added
- **DCFSegmentedControl** with icon support
- Enhanced modal behavior and child management
- Unified color management across all components
- Improved asset loading consistency

### ❌ Removed
- **DCFSwipeableView** (use DCFGestureDetector instead)
- **DCFAnimatedText** (use DCFText + DCFAnimatedView instead)

### 🔧 Improved
- Better performance and stability
- Consistent API patterns
- Enhanced adaptive theming
- Cleaner codebase architecture

## 🚀 Adding New Primitives

**Want to contribute new primitive components to DCFlight?**

👉 **Start here**: [Component Development Guidelines](../module_dev_guidelines/COMPONENT_DEVELOPMENT_GUIDELINES.md)

This comprehensive guide covers:
- Framework architecture and patterns
- Step-by-step component creation
- Testing and validation procedures
- Documentation requirements
- Contribution workflow

### Quick Links for Contributors
1. **[Development Guidelines](../module_dev_guidelines/COMPONENT_DEVELOPMENT_GUIDELINES.md)** - Complete development process
2. **[Roadmap](../module_dev_guidelines/COMPONENT_DEVELOPMENT_ROADMAP.md)** - Planned features and priorities
3. **[StyleSheet Reference](../module_dev_guidelines/STYLESHEET_REFERENCE.md)** - Styling system documentation

## 📋 Component Checklist

When working with DCFlight primitives, ensure:

- [ ] **Proper Import**: Import from `dcf_primitives` package
- [ ] **Color Format**: Use hex strings (#RRGGBB or #AARRGGBB)
- [ ] **Asset Paths**: Use Flutter asset path format
- [ ] **Adaptive Theming**: Consider `adaptive: true` for system integration
- [ ] **Event Handling**: Implement proper callback functions
- [ ] **StyleSheet**: Use StyleSheet for consistent styling

## 🔍 Finding Components

### By Native iOS Equivalent
- **UIView** → DCFView
- **UILabel** → DCFText  
- **UITextField/UITextView** → DCFTextInput
- **UIButton** → DCFButton, DCFTouchableOpacity
- **UISwitch** → DCFToggle
- **UISlider** → DCFSlider
- **UISegmentedControl** → DCFSegmentedControl
- **UIImageView** → DCFImage, DCFSvg, DCFIcon
- **UIActivityIndicatorView** → DCFSpinner
- **UITableView** → DCFVirtualizedFlatList
- **UIScrollView** → DCFVirtualizedScrollView
- **Modal Presentation** → DCFModal
- **UIAlertController** → DCFAlert

### By Flutter Widget Equivalent
- **Container** → DCFView
- **Text** → DCFText
- **TextField** → DCFTextInput
- **ElevatedButton** → DCFButton
- **Switch** → DCFToggle
- **Slider** → DCFSlider
- **Image** → DCFImage
- **CircularProgressIndicator** → DCFSpinner
- **ListView** → DCFVirtualizedFlatList
- **GestureDetector** → DCFGestureDetector

## 📞 Support & Community

- **Issues**: Report bugs and request features via the project repository
- **Contributions**: Follow the development guidelines for contributing new primitives
- **Documentation**: Help improve these docs by suggesting clarifications

---

**Ready to build amazing native experiences with DCFlight primitives!** 🚀
