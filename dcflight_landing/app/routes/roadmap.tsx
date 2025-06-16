import type { Route } from "./+types/roadmap";
import React from "react";
import { motion } from "framer-motion";
import { Link } from "react-router";
import { 
  ArrowLeft, 
  CheckCircle, 
  Clock, 
  Calendar,
  Smartphone,
  Monitor,
  Globe,
  Zap,
  Package,
  Code,
  Users,
  Heart
} from "lucide-react";

export default function Roadmap() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      {/* Navigation */}
      <nav className="bg-white/80 backdrop-blur-md border-b border-gray-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <Link to="/" className="flex items-center space-x-3 text-gray-600 hover:text-gray-900">
              <ArrowLeft size={20} />
              <span>Back to Home</span>
            </Link>
            <div className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              DCFlight Roadmap
            </div>
            <div className="w-20"></div> {/* Spacer for centering */}
          </div>
        </div>
      </nav>

      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          {/* Header */}
          <div className="text-center mb-16">
            <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-4">
              DCFlight Development Roadmap
            </h1>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              Our journey to build the future of cross-platform development. 
              Track our progress and see what's coming next.
            </p>
          </div>

          {/* Tree-based Roadmap */}
          <div className="relative">
            {/* Main trunk */}
            <div className="absolute left-1/2 transform -translate-x-1/2 w-1 bg-gradient-to-b from-green-500 via-blue-500 to-gray-300 h-full"></div>

            <div className="space-y-16">
              {/* Completed: Framework */}
              <RoadmapBranch
                status="completed"
                side="left"
                title="DCFlight Framework"
                subtitle="Core framework and architecture"
                icon={<CheckCircle className="w-8 h-8" />}
                color="green"
                items={[
                  "Virtual DOM with efficient reconciliation",
                  "React-like hooks system (useState, useStore, useEffect)",
                  "Native view management and lifecycle",
                  "Yoga layout engine integration",
                  "Hot restart support for development",
                  "Component protocol and architecture",
                  "Event system with native bridge"
                ]}
              />

              {/* In Development: iOS */}
              <RoadmapBranch
                status="in-progress"
                side="right"
                title="DCFlight iOS"
                subtitle="Native iOS implementation"
                icon={<Clock className="w-8 h-8" />}
                color="blue"
                items={[
                  "✅ DCFView - Basic container component",
                  "✅ DCFText - Text rendering with styling",
                  "✅ DCFButton - Interactive button component",
                  "✅ DCFImage - Image display with caching",
                  "✅ DCFScrollView - Scrollable container",
                  "✅ DCFTouchableOpacity - Touch interactions",
                  "✅ DCFTextInput - Text input fields",
                  "✅ DCFSafeAreaView - Safe area handling",
                  "✅ DCFGestureDetector - Gesture recognition",
                  "✅ DCFAnimatedView - View animations",
                  "✅ DCFAnimatedText - Text animations",
                  "✅ DCFSVG - SVG image support",
                  "✅ DCFIcon - Icon system",
                  "✅ DCFDropdown - Dropdown menu",
                  "🚧 DCFFlatList - High-performance lists (in progress)",
                  "📅 Modal components",
                  "📅 Navigation components",
                  "📅 Advanced animations"
                ]}
              />

              {/* Planned: Android */}
              <RoadmapBranch
                status="planned"
                side="left"
                title="DCFlight Android"
                subtitle="Native Android implementation"
                icon={<Smartphone className="w-8 h-8" />}
                color="gray"
                items={[
                  "Android component protocol design",
                  "Kotlin/Java native component implementations",
                  "Android-specific layout handling",
                  "Material Design integration",
                  "Android lifecycle management",
                  "Platform-specific optimizations"
                ]}
              />

              {/* Planned: Web */}
              <RoadmapBranch
                status="planned"
                side="right"
                title="DCFlight Web"
                subtitle="Web platform support"
                icon={<Globe className="w-8 h-8" />}
                color="gray"
                items={[
                  "DOM-based component rendering",
                  "CSS-in-Dart styling system",
                  "Web-specific event handling",
                  "Progressive Web App support",
                  "Browser compatibility layer",
                  "Performance optimizations"
                ]}
              />

              {/* Future: Advanced Features */}
              <RoadmapBranch
                status="future"
                side="left"
                title="Advanced Features"
                subtitle="Enhanced developer experience"
                icon={<Zap className="w-8 h-8" />}
                color="gray"
                items={[
                  "DCFlight DevTools browser extension",
                  "Component inspector and debugger",
                  "Performance profiling tools",
                  "Accessibility testing suite",
                  "Code generation tools",
                  "Visual component editor"
                ]}
              />

              {/* Future: Ecosystem */}
              <RoadmapBranch
                status="future"
                side="right"
                title="Ecosystem & Tooling"
                subtitle="Community and developer tools"
                icon={<Package className="w-8 h-8" />}
                color="gray"
                items={[
                  "Component marketplace",
                  "Third-party plugin system",
                  "VSCode extension with IntelliSense",
                  "Project templates and starters",
                  "Testing framework integration",
                  "CI/CD pipeline tools"
                ]}
              />
            </div>
          </div>

          {/* Call to Action */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.8, duration: 0.6 }}
            className="mt-20 text-center"
          >
            <div className="bg-gradient-to-r from-blue-600 to-purple-600 rounded-2xl p-8 text-white">
              <div className="flex items-center justify-center space-x-3 mb-4">
                <Users className="w-8 h-8" />
                <h2 className="text-3xl font-bold">Contributions Welcome!</h2>
              </div>
              <p className="text-xl text-blue-100 mb-6 max-w-2xl mx-auto">
                DCFlight is an open-source project. Help us build the future of cross-platform development.
              </p>
              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <a 
                  href="https://github.com/squirelboy360/dcflight" 
                  target="_blank"
                  rel="noopener noreferrer"
                  className="bg-white text-blue-600 px-8 py-3 rounded-lg font-medium hover:bg-gray-100 transition-colors inline-flex items-center justify-center space-x-2"
                >
                  <Code size={20} />
                  <span>Contribute on GitHub</span>
                </a>
                <a 
                  href="https://coff.ee/squirelboy360" 
                  target="_blank"
                  rel="noopener noreferrer"
                  className="bg-transparent border-2 border-white text-white px-8 py-3 rounded-lg font-medium hover:bg-white hover:text-blue-600 transition-colors inline-flex items-center justify-center space-x-2"
                >
                  <Heart size={20} />
                  <span>Support the Project</span>
                </a>
              </div>
            </div>
          </motion.div>

          {/* Timeline Legend */}
          <div className="mt-12 bg-white rounded-xl shadow-lg border border-gray-100 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Status Legend</h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <StatusLegend
                icon={<CheckCircle className="w-5 h-5 text-green-600" />}
                label="Completed"
                description="Ready to use"
              />
              <StatusLegend
                icon={<Clock className="w-5 h-5 text-blue-600" />}
                label="In Progress"
                description="Currently being developed"
              />
              <StatusLegend
                icon={<Calendar className="w-5 h-5 text-gray-500" />}
                label="Planned"
                description="Next in the roadmap"
              />
              <StatusLegend
                icon={<Zap className="w-5 h-5 text-purple-600" />}
                label="Future"
                description="Long-term goals"
              />
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}

function RoadmapBranch({ 
  status, 
  side, 
  title, 
  subtitle, 
  icon, 
  color, 
  items 
}: {
  status: 'completed' | 'in-progress' | 'planned' | 'future';
  side: 'left' | 'right';
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  color: string;
  items: string[];
}) {
  const colorClasses = {
    green: 'bg-green-100 border-green-300 text-green-800',
    blue: 'bg-blue-100 border-blue-300 text-blue-800',
    gray: 'bg-gray-100 border-gray-300 text-gray-800',
  };

  const nodeColors = {
    completed: 'bg-green-500 border-green-600',
    'in-progress': 'bg-blue-500 border-blue-600',
    planned: 'bg-gray-400 border-gray-500',
    future: 'bg-purple-500 border-purple-600',
  };

  return (
    <motion.div
      initial={{ opacity: 0, x: side === 'left' ? -50 : 50 }}
      whileInView={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.6 }}
      viewport={{ once: true }}
      className={`relative ${side === 'left' ? 'pr-8 md:pr-16' : 'pl-8 md:pl-16'}`}
    >
      {/* Branch line */}
      <div className={`absolute top-8 w-8 md:w-16 h-0.5 bg-gray-300 ${
        side === 'left' 
          ? 'right-0' 
          : 'left-0'
      }`}></div>

      {/* Node */}
      <div className={`absolute ${
        side === 'left' 
          ? 'right-[-25px] md:right-[-33px]' 
          : 'left-[-25px] md:left-[-33px]'
      } top-4 w-8 h-8 md:w-12 md:h-12 rounded-full border-4 ${nodeColors[status]} flex items-center justify-center`}>
        <div className="text-white text-lg md:text-xl">
          {status === 'completed' && '✓'}
          {status === 'in-progress' && '⚡'}
          {status === 'planned' && '○'}
          {status === 'future' && '★'}
        </div>
      </div>

      {/* Content */}
      <div className={`${side === 'left' ? 'text-right' : 'text-left'}`}>
        <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-6 max-w-md md:max-w-lg">
          <div className={`flex items-center space-x-3 mb-4 ${
            side === 'left' ? 'justify-end' : 'justify-start'
          }`}>
            <div className={side === 'left' ? 'order-2' : 'order-1'}>
              {icon}
            </div>
            <div className={side === 'left' ? 'order-1' : 'order-2'}>
              <h3 className="text-xl font-bold text-gray-900">{title}</h3>
              <p className="text-gray-600">{subtitle}</p>
            </div>
          </div>

          <div className="space-y-2">
            {items.map((item, index) => (
              <div key={index} className={`flex items-start space-x-2 text-sm ${
                side === 'left' ? 'justify-end text-right' : 'justify-start text-left'
              }`}>
                <div className={`${
                  item.startsWith('✅') ? 'text-green-600' :
                  item.startsWith('🚧') ? 'text-blue-600' :
                  item.startsWith('📅') ? 'text-gray-500' :
                  'text-gray-700'
                } ${side === 'left' ? 'order-2' : 'order-1'}`}>
                  {item}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </motion.div>
  );
}

function StatusLegend({ 
  icon, 
  label, 
  description 
}: { 
  icon: React.ReactNode; 
  label: string; 
  description: string; 
}) {
  return (
    <div className="flex items-start space-x-3">
      {icon}
      <div>
        <div className="font-medium text-gray-900">{label}</div>
        <div className="text-sm text-gray-600">{description}</div>
      </div>
    </div>
  );
}
