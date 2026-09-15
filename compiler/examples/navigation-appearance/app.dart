/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
import 'package:dcflight_authoring/dcflight.dart';
const stackColors = NavigationAppearance(accent: '#A73522', surface: '#FFF4E8');
const tabColors = TabAppearance(selectedForeground: '#A73522', unselectedForeground: '#4E5965', surface: '#FFF4E8');
App buildApp() => RoutedApp(
  id: 'com.dotcorr.navigationreview', name: 'Native appearance',
  // Explicit whole-app iOS design choice for the solid-color QA fixture.
  nativeConfiguration: const NativeConfiguration(ios: IOSConfiguration(infoPlist: {
    'UIDesignRequiresCompatibility': PlistValue.boolean(true),
  })),
  state: {'name': ''},
  navigationActions: const [NavigationAction.push('detail', id: 'openDetail'), NavigationAction.back(id: 'back'), NavigationAction.resetRoot('welcome', id: 'resetRoot'), NavigationAction.resetRoot('main', id: 'enter')],
  root: NavigationStack(id: 'applicationStack', initialRoute: 'main'),
  screens: [
    Screen(id: 'main', title: '', body: Tabs(id: 'mainTabs', appearance: tabColors, children: [
    Tab(id: 'homeTab', title: 'Home', icon: 'chat', child: NavigationStack(id: 'homeStack', initialRoute: 'home', appearance: stackColors)),
    Tab(id: 'profileTab', title: 'Profile', icon: 'user', child: NavigationStack(id: 'profileStack', initialRoute: 'profile', appearance: stackColors)),
    ])),
    Screen(id: 'welcome', title: 'Welcome', body: Button('Enter', id: 'enterButton', action: 'enter')),
    Screen(id: 'home', title: 'Home', body: Column(id: 'homeBody', style: const Style(padding: 24, gap: 16), children: [
      Text('Shared native appearance', id: 'heading'),
      TextField(id: 'nameField', value: const Ref<String>(name: 'name'), placeholder: 'Remembered name'),
      Button('Open detail', id: 'detailButton', action: 'openDetail'),
    ])),
    Screen(id: 'profile', title: 'Profile', body: Column(id: 'profileBody', children: [Text.bind(const Ref<String>(name: 'name'), id: 'profileName'), Button('Reset root', id: 'resetButton', action: 'resetRoot')])),
    Screen(id: 'detail', title: 'Detail', body: Button('Back', id: 'backButton', action: 'back')),
  ],
);
