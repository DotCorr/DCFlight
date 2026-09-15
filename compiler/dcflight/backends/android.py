from html import escape
from . import Artifact, HEADER
from .common import expression, symbol, expand
from ..ir import ScalarType, Reference


class Android:
    target = 'android'

    def generate(self, app, registry):
        files = {}
        java = 'android/app/src/main/java/' + app.id.replace('.', '/') + '/'
        def put(path, content, ownership='generated'):
            files[path] = Artifact(content, ownership)
        put('android/settings.gradle', '''pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = 'App'
include ':app'
''', 'user')
        put('android/build.gradle', "plugins { id 'com.android.application' version '8.9.2' apply false }\n", 'user')
        put('android/app/build.gradle', "plugins { id 'com.android.application' }\nandroid {\n    namespace '" + app.id + "'\n    compileSdk 35\n    defaultConfig { applicationId '" + app.id + "'; minSdk 26; targetSdk 35; versionCode 1; versionName '1.0' }\n    compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }\n}\n", 'user')
        put('android/app/src/main/AndroidManifest.xml', '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:label="''' + escape(app.name, quote=True) + '''" android:theme="@android:style/Theme.Material.Light.NoActionBar">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
    </activity>
  </application>
</manifest>
''', 'user')
        put(java + 'MainActivity.java', HEADER + 'package ' + app.id + ''';
public final class MainActivity extends android.app.Activity {
    @Override public void onCreate(android.os.Bundle savedState) {
        super.onCreate(savedState);
        AppModel model = new AppModel();
        AppScreen screen = new AppScreen(this, model);
        android.widget.FrameLayout host = new android.widget.FrameLayout(this);
        host.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(),
                insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets;
        });
        host.addView(screen.root);
        setContentView(host);
        host.requestApplyInsets();
    }
}
''', 'user')
        types = {ScalarType.STRING: 'String', ScalarType.INT: 'int', ScalarType.BOOL: 'boolean'}
        state = '\n'.join('    public ' + types[s.initial.type] + ' s_' + s.name + ' = ' + expression(s.initial, 'android') + ';' for s in app.states)
        methods = []
        for action in app.actions:
            target = 's_' + str(action.target)
            if action.operation == 'increment':
                body = target + '++;'
            elif action.operation == 'toggle':
                body = target + ' = !' + target + ';'
            elif action.operation == 'set':
                body = target + ' = ' + expression(action.value, 'android').replace('model.s_', 'this.s_') + ';'
            else:
                body = 'UserActions.a_' + action.id + '(this);'
            methods.append('    public void a_' + action.id + '() { ' + body + ' }')
        put(java + 'AppModel.java', HEADER + 'package ' + app.id + ';\npublic final class AppModel {\n' + state + '\n' + '\n'.join(methods) + '\n}\n')
        fields, builds, updates, listeners = [], [], [], []
        for node in app.nodes():
            name = symbol(node.id)
            mapping = registry.get(node.capability)['targets']['android']
            fields.append('    private final ' + mapping['className'] + ' ' + name + ';')
            if node.capability == 'native':
                builds.append(name + ' = UserViews.v_' + node.props()['symbol'].value + '(activity, model);')
            else:
                builds.append(name + ' = new ' + mapping['className'] + '(activity);')
            # Native platform accessibility uses text/control semantics; IDs remain stable for inspection.
            builds.append(name + '.setTag("' + node.id + '");')
            values = {key: expression(value, 'android') for key, value in node.properties}
            values['view'] = name
            updates.append(expand(mapping['update'], values))
            if node.action:
                listeners.append(name + '.setOnClickListener(v -> { model.a_' + node.action + '(); refresh(); });')
            if node.capability == 'toggle':
                ref = node.props()['value'].name
                listeners.append(name + '.setOnCheckedChangeListener((button, checked) -> { if (!updating) { model.s_' + ref + ' = checked; refresh(); } });')
            if node.capability == 'textField':
                ref = node.props()['value'].name
                listeners.append(name + '''.addTextChangedListener(new android.text.TextWatcher() {
                    public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
                    public void onTextChanged(CharSequence s, int start, int before, int count) {
                        if (!updating) { model.s_''' + ref + ''' = s.toString(); refresh(); }
                    }
                    public void afterTextChanged(android.text.Editable text) {}
                });''')
        # All views exist before parenting. Reordering changes this structural file only.
        for node in app.nodes():
            for child in node.children:
                height = '1' if child.capability == 'divider' else 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT'
                width = 'android.view.ViewGroup.LayoutParams.MATCH_PARENT' if child.capability == 'divider' else 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT'
                builds.append(symbol(node.id) + '.addView(' + symbol(child.id) + ', new android.widget.LinearLayout.LayoutParams(' + width + ', ' + height + '));')
        body = HEADER + 'package ' + app.id + ''';
public final class AppScreen {
    public final android.view.View root;
    private final AppModel model;
    private boolean updating;
''' + '\n'.join(fields) + '''
    public AppScreen(android.app.Activity activity, AppModel model) {
        this.model = model;
''' + '\n'.join(builds) + '\nroot = ' + symbol(app.root.id) + ';\n' + '\n'.join(listeners) + '''
        refresh();
    }
    public void refresh() {
        updating = true;
        try {
''' + '\n'.join(updates) + '''
        } finally { updating = false; }
    }
}
'''
        put(java + 'AppScreen.java', body)
        return files
