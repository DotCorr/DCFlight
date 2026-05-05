/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:flutter/material.dart';
import 'package:dcf_platform_view/dcf_platform_view.dart';

void main() {
  // Use runDCFApp instead of runApp — full pipeline control, single native surface.
  runDCFApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DCFPlatformView Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native UI in Flutter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The area below is a DCFPlatformView slot. The pipeline draws one native view (UIKit on iOS, Android View on Android) over it — you should see a tinted box with "Native UI (UIKit)" or "Native UI (Android View)". That box is real native UI embedded in Flutter.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DCFPlatformView(
                child: const Center(
                  child: Text(
                    'Flutter placeholder (native view is drawn on top by the pipeline)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
