# DCFlight Landing Page

A modern, React Native-inspired landing page for the DCFlight framework and Dotcorr agency.

## Features

### 🔄 Mesh-Based Switcher
- Toggle between Open Source (DCFlight) and Agency (Dotcorr) content
- Smooth animations and transitions
- Default focus on Open Source projects

### 📱 Cross-Platform Illustration
- SVG-based device illustrations
- Clean, modern design with connecting elements
- Responsive layout for all screen sizes

### 🌳 Tree-Based Roadmap
- Visual representation of DCFlight development progress
- Interactive branch system showing:
  - ✅ Completed features
  - 🚧 In-progress development
  - 📅 Planned features
  - ⭐ Future enhancements

### 📖 Comprehensive Documentation
- Installation instructions for both Dart and Flutter
- CLI usage guide with examples
- Complete code examples from the framework
- Development status and contribution guidelines

## Pages Structure

### Home (`/`)
- **Open Source Section**: DCFlight framework showcase
  - Hero section with framework highlights
  - Cross-platform device illustration
  - Key features overview
  - Code examples
  - Development status notice
  
- **Agency Section**: Dotcorr agency services
  - Mobile app development
  - Web development
  - UI/UX design services

### Documentation (`/docs`)
- Installation guide
- CLI commands reference
- Complete code examples
- Feature overview
- Resource links

### Roadmap (`/roadmap`)
- Tree-based visual roadmap
- Current development status
- Detailed feature lists for each phase
- Contribution call-to-action

## Design Philosophy

### Visual Design
- **Clean & Minimalistic**: Inspired by React Native website
- **Modern Flat Design**: Soft shadows and gradients
- **Light Color Palette**: Blues, grays, and whites
- **Professional Yet Approachable**: Developer-focused aesthetics

### Content Strategy
- **Framework-First**: DCFlight as the main highlight
- **Developer-Focused**: Technical accuracy and clear examples
- **Transparent**: Open about development status and bugs
- **Community-Oriented**: Emphasis on contributions and support

## Key Technical Highlights

### Framework Positioning
- **Native UI Rendering**: No Flutter widget abstraction
- **React-like DX**: Familiar hooks and component patterns
- **Performance Focus**: Direct native view access
- **Flutter Engine**: Used only for Dart runtime (like Hermes in RN)

### Code Examples
- Real examples from the framework codebase
- State management with hooks
- Component composition patterns
- Layout system demonstrations

## Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

## Technology Stack

- **React Router 7**: Modern routing and SSR
- **Tailwind CSS**: Utility-first styling
- **Framer Motion**: Smooth animations
- **Lucide React**: Consistent iconography
- **TypeScript**: Type safety

## Content Updates

### Adding New Primitives
Update the roadmap in `/app/routes/roadmap.tsx`:
- Add to the "DCFlight iOS" in-progress section
- Move completed items to ✅ status

### Framework Examples
Update code examples in `/app/routes/docs.tsx` and `/app/routes/home.tsx` to reflect latest API changes.

### Roadmap Changes
Modify the tree structure in the roadmap to reflect current development priorities.

## Deployment

The site is designed to be deployed on modern hosting platforms that support React Router SSR:
- Vercel
- Netlify
- Railway
- Cloudflare Pages

## Contributing

This landing page reflects the current state of DCFlight development. When updating:

1. Keep technical accuracy high
2. Maintain the clean, professional design
3. Update roadmap status as features are completed
4. Add new code examples as the API evolves

## Support

- **GitHub**: [DCFlight Repository](https://github.com/squirelboy360/dcflight)
- **Coffee**: [Buy me a coffee](https://coff.ee/squirelboy360)
- **Issues**: Report issues on the main DCFlight repository
