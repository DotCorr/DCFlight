import type { Route } from "./+types/docs";
import React from "react";
import { motion } from "framer-motion";
import { Link } from "react-router";
import { ArrowLeft, Copy, ExternalLink, Terminal, Package, FileText } from "lucide-react";

export default function Docs() {
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
              DCFlight Docs
            </div>
            <div className="w-20"></div> {/* Spacer for centering */}
          </div>
        </div>
      </nav>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          {/* Header */}
          <div className="text-center mb-12">
            <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-4">
              Getting Started with DCFlight
            </h1>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Build native mobile apps with Dart. No platform views, no abstractions.
            </p>
          </div>

          {/* Quick Start */}
          <section className="mb-12">
            <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-8">
              <div className="flex items-center space-x-3 mb-6">
                <Package className="w-6 h-6 text-blue-600" />
                <h2 className="text-2xl font-bold text-gray-900">Installation</h2>
              </div>
              
              <div className="space-y-4">
                <div>
                  <h3 className="text-lg font-semibold text-gray-800 mb-3">Add DCFlight to your project</h3>
                  <CodeBlock
                    code="dart pub add dcflight"
                    language="bash"
                  />
                  <p className="text-sm text-gray-600 mt-2">Or for Flutter projects:</p>
                  <CodeBlock
                    code="flutter pub add dcflight"
                    language="bash"
                  />
                </div>

                <div>
                  <h3 className="text-lg font-semibold text-gray-800 mb-3">Install DCFlight CLI</h3>
                  <CodeBlock
                    code="dart pub global activate dcflight_cli"
                    language="bash"
                  />
                </div>

                <div>
                  <h3 className="text-lg font-semibold text-gray-800 mb-3">Create a new project</h3>
                  <CodeBlock
                    code="dcf create my_app"
                    language="bash"
                  />
                </div>
              </div>
            </div>
          </section>

          {/* CLI Usage */}
          <section className="mb-12">
            <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-8">
              <div className="flex items-center space-x-3 mb-6">
                <Terminal className="w-6 h-6 text-blue-600" />
                <h2 className="text-2xl font-bold text-gray-900">CLI Commands</h2>
              </div>
              
              <div className="space-y-6">
                <CLICommand
                  command="dcf create [project_name]"
                  description="Create a new DCFlight project with all necessary boilerplate"
                />
                <CLICommand
                  command="dcf add [package_name]"
                  description="Add packages to your DCFlight project"
                />
                <CLICommand
                  command="dcf run"
                  description="Run your DCFlight app with hot reload support"
                />
              </div>
            </div>
          </section>

          {/* Code Example */}
          <section className="mb-12">
            <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-8">
              <div className="flex items-center space-x-3 mb-6">
                <FileText className="w-6 h-6 text-blue-600" />
                <h2 className="text-2xl font-bold text-gray-900">Basic Example</h2>
              </div>
              
              <p className="text-gray-600 mb-4">
                Here's a complete example of a DCFlight app with state management and user interactions:
              </p>

              <CodeBlock
                code={`void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final globalCounter = useStore(globalCounterState);
    final counter = useState(0);
    
    return DCFSafeAreaView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFScrollView(
          showsScrollIndicator: true,
          style: StyleSheet(backgroundColor: Colors.white),
          layout: LayoutProps(
            paddingHorizontal: 20,
            justifyContent: YogaJustifyContent.spaceBetween,
            flex: 1,
            flexDirection: YogaFlexDirection.column,
          ),
          children: [
            DCFText(
              content: "Counter: \${counter.value}",
              textProps: DCFTextProps(
                fontSize: 24,
                fontWeight: "bold",
                color: Colors.black,
              ),
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Increment"),
              onPress: () {
                counter.setValue(counter.value + 1);
                globalCounter.setState(globalCounter.state + 1);
              },
            ),
            DCFText(
              content: "Global: \${globalCounter.state}",
              textProps: DCFTextProps(fontSize: 18),
            ),
          ],
        ),
      ],
    );
  }
}

// Global state example
final globalCounterState = Store<int>(0);`}
                language="dart"
              />
            </div>
          </section>

          {/* Key Features */}
          <section className="mb-12">
            <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-8">
              <h2 className="text-2xl font-bold text-gray-900 mb-6">Key Features</h2>
              
              <div className="grid md:grid-cols-2 gap-6">
                <FeatureItem
                  title="Native Performance"
                  description="DCFlight renders actual native UI components, not Flutter widgets. No bridge overhead."
                />
                <FeatureItem
                  title="React-like API"
                  description="Familiar hooks-based state management with useState, useStore, and useEffect."
                />
                <FeatureItem
                  title="Yoga Layout"
                  description="Powerful flexbox-style layout system for responsive UIs across all screen sizes."
                />
                <FeatureItem
                  title="Hot Restart Support"
                  description="Fast development cycle with hot restart detection and automatic cleanup."
                />
                <FeatureItem
                  title="No Abstractions"
                  description="Direct access to native views without unnecessary platform view overhead."
                />
                <FeatureItem
                  title="Flutter Compatibility"
                  description="Can render Flutter widgets via WidgetToDCFAdaptor when needed."
                />
              </div>
            </div>
          </section>

          {/* Development Status */}
          <section className="mb-12">
            <div className="bg-yellow-50 border border-yellow-200 rounded-xl p-8">
              <h2 className="text-2xl font-bold text-yellow-800 mb-4">🚧 Development Status</h2>
              <div className="space-y-3 text-yellow-700">
                <p>
                  <strong>DCFlight is under rapid development.</strong> The framework is functional but expect:
                </p>
                <ul className="list-disc list-inside space-y-1 ml-4">
                  <li>Breaking changes as APIs stabilize</li>
                  <li>Bugs and rough edges in current implementation</li>
                  <li>Limited documentation (we're working on it!)</li>
                  <li>iOS support is primary focus, Android coming soon</li>
                </ul>
                <p>
                  <strong>Contributions are welcomed!</strong> Help us build the future of cross-platform development.
                </p>
              </div>
            </div>
          </section>

          {/* Links */}
          <section>
            <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-8">
              <h2 className="text-2xl font-bold text-gray-900 mb-6">Resources</h2>
              
              <div className="grid md:grid-cols-2 gap-4">
                <ResourceLink
                  href="https://github.com/squirelboy360/dcflight"
                  title="GitHub Repository"
                  description="Source code, issues, and contributions"
                />
                <ResourceLink
                  href="https://coff.ee/squirelboy360"
                  title="Support Development"
                  description="Buy the developer a coffee"
                />
                <ResourceLink
                  href="/roadmap"
                  title="Roadmap"
                  description="See what's planned for DCFlight"
                  internal
                />
                <ResourceLink
                  href="#"
                  title="Examples"
                  description="Sample projects and code snippets"
                />
              </div>
            </div>
          </section>
        </motion.div>
      </div>
    </div>
  );
}

function CodeBlock({ code, language }: { code: string; language: string }) {
  const copyToClipboard = () => {
    navigator.clipboard.writeText(code);
  };

  return (
    <div className="relative">
      <div className="bg-gray-900 rounded-lg p-4 overflow-x-auto">
        <button
          onClick={copyToClipboard}
          className="absolute top-2 right-2 p-2 text-gray-400 hover:text-white transition-colors"
        >
          <Copy size={16} />
        </button>
        <pre className="text-green-400 text-sm">
          <code>{code}</code>
        </pre>
      </div>
    </div>
  );
}

function CLICommand({ command, description }: { command: string; description: string }) {
  return (
    <div className="border-l-4 border-blue-500 pl-4">
      <code className="text-blue-600 font-mono text-sm bg-blue-50 px-2 py-1 rounded">
        {command}
      </code>
      <p className="text-gray-600 mt-2">{description}</p>
    </div>
  );
}

function FeatureItem({ title, description }: { title: string; description: string }) {
  return (
    <div className="space-y-2">
      <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
      <p className="text-gray-600">{description}</p>
    </div>
  );
}

function ResourceLink({ 
  href, 
  title, 
  description, 
  internal = false 
}: { 
  href: string; 
  title: string; 
  description: string; 
  internal?: boolean; 
}) {
  const baseClasses = "block p-4 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 transition-colors";
  
  const content = (
    <>
      <div className="flex items-center space-x-2 text-blue-600 font-medium">
        <span>{title}</span>
        <ExternalLink size={16} />
      </div>
      <p className="text-gray-600 text-sm mt-1">{description}</p>
    </>
  );

  if (internal) {
    return (
      <Link to={href} className={baseClasses}>
        {content}
      </Link>
    );
  }

  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className={baseClasses}>
      {content}
    </a>
  );
}
