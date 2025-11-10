# Contributing to DCFlight

Thank you for your interest in contributing to DCFlight! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [Making Changes](#making-changes)
5. [Submitting Changes](#submitting-changes)
6. [Code Review Process](#code-review-process)
7. [Issue Reporting](#issue-reporting)
8. [Feature Requests](#feature-requests)

---

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

---

## Getting Started

### Prerequisites

- Dart SDK (3.6.1 or higher)
- Flutter SDK (latest stable)
- Android Studio / Xcode (for native development)
- Git

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/dcflight.git
   cd dcflight
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/dotcorr/dcflight.git
   ```

---

## Development Setup

### 1. Install Dependencies

```bash
# Install Dart dependencies
flutter pub get

# Install CLI dependencies
cd cli
dart pub get
cd ..
```

### 2. Run Tests

```bash
# Run all tests
flutter test

# Run tests for specific package
cd packages/dcflight
flutter test
```

### 3. Build the CLI

```bash
cd cli
dart pub get
dart compile exe bin/dcflight_cli.dart -o bin/dcf
```

---

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/component-name` - New features
- `fix/issue-description` - Bug fixes
- `docs/update-guide` - Documentation updates
- `refactor/component-name` - Code refactoring

### Commit Messages

Follow conventional commit format:

```
type(scope): subject

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(components): add DCFButton component

fix(android): resolve layout calculation issue

docs(guide): update component development guidelines
```

### Code Style

#### Dart

- Run `dart format .` before committing
- Follow the Dart style guide
- Use `dart analyze` to check for issues

#### Kotlin

- Follow Kotlin style guide
- Use KDoc for documentation
- Handle nullability explicitly

#### Swift

- Follow Swift style guide
- Use SwiftLint if available
- Use doc comments for public APIs

### Testing

- Add tests for new features
- Ensure all tests pass before submitting
- Test on both Android and iOS when applicable
- Include integration tests for complex features

---

## Submitting Changes

### 1. Update Your Fork

```bash
git fetch upstream
git checkout main
git merge upstream/main
```

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

### 3. Make Your Changes

- Write clean, well-documented code
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 4. Commit Your Changes

```bash
git add .
git commit -m "feat(scope): your commit message"
```

### 5. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 6. Create a Pull Request

1. Go to the GitHub repository
2. Click "New Pull Request"
3. Select your branch
4. Fill out the PR template
5. Submit the PR

---

## Code Review Process

### What to Expect

- All PRs require at least one approval
- Reviewers may request changes
- Be responsive to feedback
- Address all review comments

### Review Checklist

Before requesting review, ensure:

- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] No breaking changes (or documented)
- [ ] Cross-platform tested (if applicable)
- [ ] Commit messages follow conventions

### Responding to Reviews

- Be respectful and professional
- Address all comments
- Ask questions if something is unclear
- Update your PR based on feedback

---

## Issue Reporting

### Before Reporting

1. Check existing issues
2. Search closed issues
3. Verify it's a bug, not expected behavior
4. Check documentation

### Bug Report Template

```markdown
**Description**
Clear description of the bug

**Steps to Reproduce**
1. Step one
2. Step two
3. Step three

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- DCFlight version:
- Flutter version:
- Dart version:
- Platform: iOS/Android/Both
- Device/Simulator:

**Screenshots**
If applicable

**Additional Context**
Any other relevant information
```

### Security Issues

**Do not** report security vulnerabilities publicly. Instead, email security@dotcorr.com with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

---

## Feature Requests

### Feature Request Template

```markdown
**Feature Description**
Clear description of the feature

**Use Case**
Why is this feature needed?

**Proposed Solution**
How should this feature work?

**Alternatives Considered**
Other approaches you've considered

**Additional Context**
Any other relevant information
```

### Feature Request Process

1. Open an issue with the feature request
2. Discuss the feature with maintainers
3. Get approval before implementing
4. Implement following contribution guidelines
5. Submit PR with implementation

---

## Component Development

### Adding New Components

1. **Create Native Components**
   - Android: `packages/dcf_primitives/android/.../components/`
   - iOS: `packages/dcf_primitives/ios/Classes/Components/`

2. **Create Dart Interface**
   - Location: `packages/dcf_primitives/lib/src/components/`

3. **Register Components**
   - Android: `PrimitivesComponentsReg.kt`
   - iOS: `PrimitivesComponentsReg.swift`

4. **Add Tests**
   - Unit tests for props
   - Integration tests for behavior

5. **Update Documentation**
   - Component API documentation
   - Usage examples

### Component Guidelines

- Ensure cross-platform consistency
- Follow naming conventions
- Document all props
- Handle edge cases
- Test on both platforms

See [FRAMEWORK_GUIDELINES.md](FRAMEWORK_GUIDELINES.md) for detailed component development instructions.

---

## Module Development

### Creating Modules

Use the CLI to create modules:

```bash
dcf create module
```

See `packages/template/dcf_module/GUIDELINES.md` for module development guidelines.

### Module Contribution

- Modules should be self-contained
- Minimize external dependencies
- Provide clear documentation
- Include usage examples
- Test thoroughly

---

## Documentation

### Documentation Types

1. **Code Documentation**: Doc comments in code
2. **API Documentation**: Component and API references
3. **Guides**: Development and usage guides
4. **Examples**: Code examples and demos

### Documentation Guidelines

- Keep documentation up to date
- Use clear, concise language
- Include code examples
- Link to related documentation
- Update when making changes

---

## Release Process

Releases are managed by maintainers. Contributors don't need to worry about versioning, but should:

- Follow semantic versioning principles
- Note breaking changes in PRs
- Update CHANGELOG.md for significant changes

---

## Getting Help

### Resources

- [Framework Guidelines](FRAMEWORK_GUIDELINES.md)
- [Component Protocol](docs/COMPONENT_PROTOCOL.md)
- [Event System](docs/EVENT_SYSTEM.md)
- [Module Guidelines](packages/template/dcf_module/GUIDELINES.md)

### Communication

- **Issues**: Use GitHub issues for bugs and features
- **Discussions**: Use GitHub discussions for questions
- **Pull Requests**: Use PR comments for code-related questions

---

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md (if applicable)
- Credited in release notes for significant contributions
- Appreciated by the community! 🙏

---

## Questions?

If you have questions about contributing:

1. Check existing documentation
2. Search existing issues
3. Open a discussion on GitHub
4. Ask in your PR comments

Thank you for contributing to DCFlight! 🚀

