import type { Route } from "./+types/home";
import React, { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Github, ExternalLink, Coffee, FileText, Map, Monitor, Smartphone, Tablet } from "lucide-react";
import { Link } from "react-router";

export default function Home() {
  const [activeSection, setActiveSection] = useState<'opensource' | 'agency'>('opensource');

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      {/* Navigation */}
      <nav className="bg-white/80 backdrop-blur-md border-b border-gray-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-4">
              <div className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                Dotcorr
              </div>
              
              {/* Mesh-based switcher */}
              <div className="hidden md:flex bg-gray-100 rounded-full p-1">
                <button
                  onClick={() => setActiveSection('opensource')}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                    activeSection === 'opensource'
                      ? 'bg-white text-blue-600 shadow-sm'
                      : 'text-gray-600 hover:text-gray-900'
                  }`}
                >
                  Open Source
                </button>
                <button
                  onClick={() => setActiveSection('agency')}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                    activeSection === 'agency'
                      ? 'bg-white text-blue-600 shadow-sm'
                      : 'text-gray-600 hover:text-gray-900'
                  }`}
                >
                  Agency
                </button>
              </div>
            </div>

            <div className="flex items-center space-x-6">
              <Link to="/docs" className="text-gray-600 hover:text-gray-900 flex items-center space-x-1">
                <FileText size={16} />
                <span>Docs</span>
              </Link>
              <Link to="/roadmap" className="text-gray-600 hover:text-gray-900 flex items-center space-x-1">
                <Map size={16} />
                <span>Roadmap</span>
              </Link>
              <a 
                href="https://github.com/squirelboy360/dcflight" 
                className="text-gray-600 hover:text-gray-900"
                target="_blank"
                rel="noopener noreferrer"
              >
                <Github size={20} />
              </a>
            </div>
          </div>
        </div>
      </nav>

      <AnimatePresence mode="wait">
        {activeSection === 'opensource' ? (
          <OpenSourceSection key="opensource" />
        ) : (
          <AgencySection key="agency" />
        )}
      </AnimatePresence>

      {/* Footer */}
      <footer className="bg-white border-t border-gray-200 py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-center">
            {/* Copyright and Description */}
            <div className="text-center md:text-left">
              <div className="text-gray-600 mb-2">
                © 2025 Dotcorr. Building the future of cross-platform development.
              </div>
              <div className="text-sm text-gray-500">
                Open source framework for native mobile development with Dart.
              </div>
            </div>

            {/* Contact Information */}
            <div className="text-center">
              <h4 className="font-semibold text-gray-900 mb-3">Get in Touch</h4>
              <div className="space-y-2">
                <a 
                  href="mailto:squirelwares@gmail.com"
                  className="block text-gray-600 hover:text-blue-600 transition-colors text-sm"
                >
                  📧 squirelwares@gmail.com
                </a>
                <a 
                  href="https://x.com/squirelBoy360"
                  target="_blank"
                  rel="noopener noreferrer" 
                  className="block text-gray-600 hover:text-blue-600 transition-colors text-sm"
                >
                  🐦 @squirelBoy360
                </a>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex flex-col sm:flex-row items-center justify-center md:justify-end space-y-3 sm:space-y-0 sm:space-x-4">
              <a 
                href="https://coff.ee/squirelboy360" 
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center space-x-2 bg-yellow-400 hover:bg-yellow-500 text-black px-4 py-2 rounded-lg transition-colors"
              >
                <Coffee size={16} />
                <span>Buy me a coffee</span>
              </a>
              <a 
                href="https://github.com/squirelboy360/dcflight" 
                target="_blank"
                rel="noopener noreferrer"
                className="text-gray-600 hover:text-gray-900 transition-colors"
              >
                <Github size={20} />
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

function OpenSourceSection() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.3 }}
    >
      {/* Hero Section */}
      <section className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1, duration: 0.6 }}
          >
            <h1 className="text-5xl md:text-6xl font-bold text-gray-900 mb-6">
              <span className="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                DCFlight
              </span>
            </h1>
            <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
              Build native mobile apps with Dart. No platform views, no abstractions. 
              Just pure native UI with React-like development experience.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link 
                to="/docs"
                className="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 rounded-lg font-medium transition-colors inline-flex items-center justify-center space-x-2"
              >
                <span>Get Started</span>
                <ExternalLink size={16} />
              </Link>
              <a 
                href="https://github.com/squirelboy360/dcflight" 
                target="_blank"
                rel="noopener noreferrer"
                className="border border-gray-300 hover:border-gray-400 text-gray-700 px-8 py-3 rounded-lg font-medium transition-colors inline-flex items-center justify-center space-x-2"
              >
                <Github size={16} />
                <span>View on GitHub</span>
              </a>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Cross-Platform Illustration */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-4">One Codebase, Multiple Platforms</h2>
            <p className="text-gray-600 max-w-2xl mx-auto">
              Write once in Dart, render native UI everywhere. DCFlight brings React-like development to native mobile.
            </p>
          </div>
          
          <CrossPlatformIllustration />
        </div>
      </section>

      {/* Key Features */}
      <section className="py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-3 gap-8">
            <FeatureCard
              icon="🚀"
              title="Native Performance"
              description="Renders actual native UI components. No bridge overhead, no compromise on performance."
            />
            <FeatureCard
              icon="⚛️"
              title="Best of Flutter DX and React"
              description="Familiar development experience with hooks, state management, and component lifecycle."
            />
            <FeatureCard
              icon="🎨"
              title="No Abstractions"
              description="Direct access to native views. No platform views or unnecessary abstractions."
            />
          </div>
        </div>
      </section>

      {/* Code Example */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-4">Simple, Powerful API</h2>
            <p className="text-gray-600">Build complex UIs with intuitive Dart syntax</p>
          </div>
          
          <div className="bg-gray-900 rounded-lg p-3 sm:p-4 lg:p-6 overflow-hidden">
            <div className="flex items-center justify-between mb-3 sm:mb-4">
              <div className="flex space-x-1">
                <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-red-400 rounded-full"></div>
                <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-yellow-400 rounded-full"></div>
                <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-green-400 rounded-full"></div>
              </div>
              <span className="text-gray-400 text-xs font-mono">main.dart</span>
            </div>
            <div className="overflow-x-auto">
              <pre className="text-green-400 text-xs sm:text-sm leading-relaxed font-mono whitespace-pre" style={{ minWidth: 'max-content' }}>
{`void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useState(0);
    
    return DCFView(
      layout: LayoutProps(
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      children: [
        DCFText(
          content: "Count: \${counter.value}",
          textProps: DCFTextProps(fontSize: 24),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Increment"),
          onPress: () => counter.setValue(counter.value + 1),
        ),
      ],
    );
  }
}`}
              </pre>
            </div>
          </div>
        </div>
      </section>

      {/* Under Development Notice */}
      <section className="py-16">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-8">
            <h3 className="text-2xl font-bold text-yellow-800 mb-4">🚧 Under Active Development</h3>
            <p className="text-yellow-700 mb-4">
              DCFlight is currently in rapid development. Expect bugs and breaking changes as we work towards stability.
            </p>
            <p className="text-yellow-600">
              Contributions are welcomed! Help us build the future of cross-platform development.
            </p>
          </div>
        </div>
      </section>
    </motion.div>
  );
}

function AgencySection() {
  const [showContact, setShowContact] = useState(false);

  const handleStartProject = () => {
    setShowContact(true);
    // Auto-hide after 5 seconds
    setTimeout(() => setShowContact(false), 5000);
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.3 }}
    >
      <section className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 className="text-5xl md:text-6xl font-bold text-gray-900 mb-6">
            <span className="bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent">
              Dotcorr Agency
            </span>
          </h1>
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
            We build beautiful apps and websites for people. Specializing in mobile development 
            and modern web experiences.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <button 
              onClick={handleStartProject}
              className="bg-purple-600 hover:bg-purple-700 text-white px-8 py-3 rounded-lg font-medium transition-colors"
            >
              Start a Project
            </button>
            <button 
              disabled
              className="border border-gray-200 text-gray-400 px-8 py-3 rounded-lg font-medium cursor-not-allowed opacity-60"
              title="Coming Soon"
            >
              View Portfolio
            </button>
          </div>

          {/* Contact Toast */}
          <AnimatePresence>
            {showContact && (
              <motion.div
                initial={{ opacity: 0, y: 20, scale: 0.9 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: -20, scale: 0.9 }}
                transition={{ duration: 0.3 }}
                className="fixed top-20 right-4 bg-white border border-gray-200 rounded-lg shadow-lg p-6 z-50 max-w-sm"
              >
                <div className="flex justify-between items-start mb-4">
                  <h3 className="font-semibold text-gray-900">Get in Touch</h3>
                  <button 
                    onClick={() => setShowContact(false)}
                    className="text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    ×
                  </button>
                </div>
                <div className="space-y-3">
                  <a 
                    href="mailto:squirelwares@gmail.com"
                    className="flex items-center space-x-2 text-gray-600 hover:text-purple-600 transition-colors"
                  >
                    <span>📧</span>
                    <span className="text-sm">squirelwares@gmail.com</span>
                  </a>
                  <a 
                    href="https://x.com/squirelBoy360"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center space-x-2 text-gray-600 hover:text-purple-600 transition-colors"
                  >
                    <span>🐦</span>
                    <span className="text-sm">@squirelBoy360</span>
                  </a>
                </div>
                <p className="text-xs text-gray-500 mt-4">
                  Reach out to discuss your project needs!
                </p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </section>

      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-3 gap-8">
            <FeatureCard
              icon="📱"
              title="Mobile Apps"
              description="Native iOS and Android apps built with modern frameworks and best practices."
            />
            <FeatureCard
              icon="🌐"
              title="Web Development"
              description="Fast, responsive websites and web applications that deliver exceptional user experiences."
            />
            <FeatureCard
              icon="🎨"
              title="UI/UX Design"
              description="Beautiful, intuitive designs that put users first and drive business results."
            />
          </div>
        </div>
      </section>
    </motion.div>
  );
}

function CrossPlatformIllustration() {
  return (
    <div className="py-16 bg-gradient-to-br from-white via-blue-50/30 to-purple-50/20">
      <div className="max-w-7xl mx-auto px-4">
        
        {/* Code Editor at Top */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1, duration: 0.8, ease: "easeOut" }}
          viewport={{ once: true }}
          className="flex justify-center mb-16"
        >
          <div className="bg-gray-900 rounded-xl p-6 shadow-lg border border-gray-700 w-full max-w-2xl">
            <div className="flex items-center justify-between mb-4">
              <div className="flex space-x-2">
                <div className="w-3 h-3 bg-red-400 rounded-full"></div>
                <div className="w-3 h-3 bg-yellow-400 rounded-full"></div>
                <div className="w-3 h-3 bg-green-400 rounded-full"></div>
              </div>
              <span className="text-gray-400 text-sm font-mono">main.dart</span>
            </div>
            <pre className="text-green-400 text-sm leading-relaxed font-mono">
{`DCFView(
  children: [
    DCFText(
      "Hello DCFlight!"
    ),
    DCFButton(
      title: "Click me",
      onPress: () {
        // Native action
      }
    )
  ]
)`}
            </pre>
          </div>
        </motion.div>

        {/* Three Platforms Horizontally at Bottom */}
        <div className="flex flex-col lg:flex-row justify-center items-center lg:items-end space-y-8 lg:space-y-0 lg:space-x-16">
          
          {/* iOS */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.8 }}
            viewport={{ once: true }}
            className="flex flex-col items-center"
          >
            <div className="w-48 h-80 bg-gray-900 rounded-[20px] p-2 shadow-lg">
              <div className="w-full h-full bg-white rounded-[18px] relative overflow-hidden">
                {/* Notch */}
                <div className="absolute top-2 left-1/2 transform -translate-x-1/2 w-12 h-1.5 bg-gray-800 rounded-full"></div>
                {/* Status Bar */}
                <div className="pt-6 px-3 flex justify-between text-xs text-gray-800">
                  <span>9:41</span>
                  <span>100%</span>
                </div>
                {/* Content */}
                <div className="px-3 py-6 flex flex-col items-center justify-center space-y-3 h-full">
                  <div className="text-center">
                    <div className="text-base font-medium text-gray-800 mb-3">Hello DCFlight!</div>
                    <div className="w-20 h-8 bg-blue-500 rounded-lg flex items-center justify-center">
                      <span className="text-white text-sm font-medium">Click me</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            
            <div className="mt-4 flex items-center space-x-2">
              <div className="w-6 h-6 bg-gray-100 rounded-lg flex items-center justify-center">
                <svg viewBox="0 0 24 24" className="w-4 h-4 fill-gray-600">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                </svg>
              </div>
              <span className="font-medium text-gray-700">iOS</span>
            </div>
          </motion.div>

          {/* Android */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.8 }}
            viewport={{ once: true }}
            className="flex flex-col items-center"
          >
            <div className="w-48 h-80 bg-gray-900 rounded-[20px] p-2 shadow-lg">
              <div className="w-full h-full bg-white rounded-[18px] relative overflow-hidden">
                {/* Camera hole */}
                <div className="absolute top-2.5 left-1/2 transform -translate-x-1/2 w-2.5 h-2.5 bg-gray-800 rounded-full"></div>
                {/* Status Bar */}
                <div className="pt-6 px-3 flex justify-between text-xs text-gray-800">
                  <span>9:41</span>
                  <span>100%</span>
                </div>
                {/* Content */}
                <div className="px-3 py-6 flex flex-col items-center justify-center space-y-3 h-full">
                  <div className="text-center">
                    <div className="text-base font-medium text-gray-800 mb-3">Hello DCFlight!</div>
                    <div className="w-20 h-8 bg-green-500 rounded-lg flex items-center justify-center">
                      <span className="text-white text-sm font-medium">Click me</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            
            <div className="mt-4 flex items-center space-x-2">
              <div className="w-6 h-6 bg-green-100 rounded-lg flex items-center justify-center">
                <svg viewBox="0 0 24 24" className="w-4 h-4 fill-green-600">
                  <path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85a.637.637 0 0 0-.83.22l-1.88 3.24a11.43 11.43 0 0 0-8.94 0L5.65 5.67a.637.637 0 0 0-.83-.22c-.3.16-.42.54-.26.85L6.4 9.48C3.3 11.25 1.28 14.44 1 18h22c-.28-3.56-2.3-6.75-5.4-8.52zM7 15.25a1.25 1.25 0 1 1 2.5 0 1.25 1.25 0 0 1-2.5 0zm7.5 0a1.25 1.25 0 1 1 2.5 0 1.25 1.25 0 0 1-2.5 0z"/>
                </svg>
              </div>
              <span className="font-medium text-gray-700">Android</span>
            </div>
          </motion.div>

          {/* Web Browser */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4, duration: 0.8 }}
            viewport={{ once: true }}
            className="flex flex-col items-center"
          >
            <div className="w-64 h-80 bg-gray-200 rounded-t-xl shadow-lg overflow-hidden">
              {/* Browser Chrome */}
              <div className="h-10 bg-gray-300 flex items-center px-3">
                <div className="flex space-x-1">
                  <div className="w-2.5 h-2.5 bg-red-400 rounded-full"></div>
                  <div className="w-2.5 h-2.5 bg-yellow-400 rounded-full"></div>
                  <div className="w-2.5 h-2.5 bg-green-400 rounded-full"></div>
                </div>
                <div className="flex-1 mx-3 h-5 bg-white rounded-md flex items-center px-2">
                  <span className="text-xs text-gray-500">localhost:3000</span>
                </div>
              </div>
              {/* Content Area */}
              <div className="h-full bg-white p-6 flex flex-col items-center justify-center">
                <div className="text-center">
                  <div className="text-lg font-medium text-gray-800 mb-4">Hello DCFlight!</div>
                  <div className="w-24 h-10 bg-purple-500 rounded-lg flex items-center justify-center">
                    <span className="text-white text-sm font-medium">Click me</span>
                  </div>
                </div>
              </div>
            </div>
            
            <div className="mt-4 flex items-center space-x-2">
              <div className="flex space-x-1">
                <div className="w-5 h-5 bg-gradient-to-br from-red-400 via-yellow-400 to-green-400 rounded-full relative">
                  <div className="absolute inset-0.5 bg-blue-500 rounded-full"></div>
                  <div className="absolute inset-1 bg-white rounded-full"></div>
                </div>
                <div className="w-5 h-5 bg-gradient-to-br from-orange-400 to-red-500 rounded-full"></div>
                <div className="w-5 h-5 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full"></div>
              </div>
              <span className="font-medium text-gray-700">Web</span>
            </div>
          </motion.div>
        </div>

        {/* Connectivity indicator */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6, duration: 0.8 }}
          viewport={{ once: true }}
          className="text-center mt-16"
        >
          <div className="inline-flex items-center space-x-3 bg-white rounded-full px-6 py-3 shadow-lg border border-gray-200">
            <span className="w-2.5 h-2.5 bg-green-400 rounded-full animate-pulse"></span>
            <span className="text-gray-700 font-medium">One codebase, all platforms</span>
          </div>
        </motion.div>
      </div>
    </div>
  );
}

function DeviceCard({ icon, label, color }: { icon: React.ReactNode; label: string; color: string }) {
  return (
    <motion.div
      whileHover={{ scale: 1.05 }}
      className={`${color} p-6 rounded-2xl shadow-lg flex flex-col items-center space-y-3 min-w-[120px]`}
    >
      {icon}
      <span className="font-medium text-gray-700">{label}</span>
    </motion.div>
  );
}

function FeatureCard({ icon, title, description }: { icon: string; title: string; description: string }) {
  return (
    <motion.div
      whileHover={{ y: -5 }}
      className="bg-white p-6 rounded-xl shadow-lg border border-gray-100"
    >
      <div className="text-3xl mb-4">{icon}</div>
      <h3 className="text-xl font-semibold text-gray-900 mb-3">{title}</h3>
      <p className="text-gray-600">{description}</p>
    </motion.div>
  );
}
