import 'package:dcflight_authoring/dcflight.dart';

// Every product word, field order, spacing and route destination is authored here.
// This verifies framework source ownership; it is not a pretend authenticated app.
const page = Style(padding: 24, gap: 16, fill: true);
const title = Style(fontSize: 32, fontWeight: 'bold', color: '#18191C');
const primary = Style(background: '#FFDD33', color: '#18191C', radius: 20, padding: 12);

App buildApp() => RoutedApp(
  id: 'com.dotcorr.sharedsource', name: 'Shared source verification',
  state: {'displayName': '', 'username': '', 'reminders': false},
  navigationActions: const [
    NavigationAction.push('main', id: 'continueToMain'),
    NavigationAction.push('details', id: 'openDetails'),
    NavigationAction.present('settings', id: 'openSettings'),
    NavigationAction.dismiss(id: 'closeSettings'),
    NavigationAction.back(id: 'goBack'),
  ],
  root: NavigationStack(id: 'applicationNavigation', initialRoute: 'welcome'),
  screens: [
    Screen(id: 'welcome', title: '', body: Scroll(id: 'welcomeScroll', children: [
      Column(id: 'welcomeForm', style: page, children: [
        Text('One app. One source.', id: 'welcomeTitle', style: title),
        Text('The same authored form on both platforms.', id: 'welcomeSubtitle'),
        Text('Display name', id: 'displayNameLabel'),
        TextField(id: 'displayNameField', value: const Ref<String>(name: 'displayName'), placeholder: 'How friends see you'),
        Text('Username', id: 'usernameLabel'),
        TextField(id: 'usernameField', value: const Ref<String>(name: 'username'), placeholder: 'Choose a username'),
        Button('Continue', id: 'continueButton', action: 'continueToMain', style: primary),
      ]),
    ])),
    Screen(id: 'main', title: '', body: Tabs(id: 'mainTabs', children: [
      Tab(id: 'homeTab', title: 'Home', icon: 'chat', child: NavigationStack(id: 'homeStack', initialRoute: 'home')),
      Tab(id: 'profileTab', title: 'You', icon: 'user', child: NavigationStack(id: 'profileStack', initialRoute: 'profile')),
    ])),
    Screen(id: 'home', title: 'Home', body: Column(id: 'homeBody', style: page, children: [
      Text('Your shared screen', id: 'homeTitle', style: title),
      Text.bind(const Ref<String>(name: 'displayName'), id: 'sharedName'),
      Button('Open details', id: 'detailsButton', action: 'openDetails', style: primary),
    ])),
    Screen(id: 'profile', title: 'You', body: Column(id: 'profileBody', style: page, children: [
      Text.bind(const Ref<String>(name: 'username'), id: 'sharedUsername', style: title),
      Button('Settings', id: 'settingsButton', action: 'openSettings', style: primary),
    ])),
    Screen(id: 'details', title: 'Details', body: Column(id: 'detailsBody', style: page, children: [
      Text('This destination is declared once.', id: 'detailsText'),
      Button('Back', id: 'backButton', action: 'goBack'),
    ])),
    Screen(id: 'settings', title: 'Settings', presentation: ScreenPresentation.sheet,
      body: Column(id: 'settingsBody', style: page, children: [
        Toggle('Reminders', id: 'remindersToggle', value: const Ref<bool>(name: 'reminders')),
        Button('Done', id: 'doneButton', action: 'closeSettings', style: primary),
      ])),
  ],
);
