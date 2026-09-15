from html import escape
from . import Artifact, HEADER
from .common import color_java, expression, symbol, expand
from ..ir import ScalarType, Reference


TEXT_CAPABILITIES = ('text', 'counter', 'button', 'toggle', 'textField')
WEIGHTS_ANDROID = {'medium': 'MEDIUM', 'semibold': 'SEMI_BOLD', 'bold': 'BOLD'}
GRAVITIES_ANDROID = {'start': 'android.view.Gravity.START', 'center': 'android.view.Gravity.CENTER', 'end': 'android.view.Gravity.END'}


def android_text_style(name, capability, style, lines):
    if 'color' in style and capability in ('text', 'counter', 'textField', 'button', 'toggle'):
        lines.append(name + '.setTextColor(android.graphics.Color.parseColor("' + color_java(style['color']) + '"));')
    if 'fontSize' in style and capability in TEXT_CAPABILITIES:
        lines.append(name + '.setTextSize(android.util.TypedValue.COMPLEX_UNIT_DIP, %d);' % style['fontSize'])
    weight = style.get('fontWeight')
    if weight and capability in ('text', 'counter', 'textField', 'button', 'toggle'):
        lines.append(name + '.setTypeface(android.graphics.Typeface.create(android.graphics.Typeface.SANS_SERIF, android.graphics.Typeface.' + WEIGHTS_ANDROID[weight] + '));')
    if capability == 'button':
        lines.append(name + '.setAllCaps(false);')
    if capability == 'progress' and 'color' in style:
        lines.append(name + '.getIndeterminateDrawable().setTint(android.graphics.Color.parseColor("' + color_java(style['color']) + '"));')


def android_box_style(name, style, lines):
    if style.get('padding'):
        pads = ('%d * dp' % style['padding'],) * 4
        lines.append(name + '.setPadding(%s, %s, %s, %s);' % pads)
    if 'backgroundColor' in style:
        lines.append('android.graphics.drawable.GradientDrawable styled_' + name + ' = new android.graphics.drawable.GradientDrawable();')
        lines.append('styled_' + name + '.setColor(android.graphics.Color.parseColor("' + color_java(style['backgroundColor']) + '"));')
        lines.append('styled_' + name + '.setCornerRadius(%d * dp);' % style.get('cornerRadius', 0))
        lines.append(name + '.setBackground(styled_' + name + ');')


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
        host.setBackgroundColor(android.graphics.Color.parseColor("__ROOT_BG__"));
        host.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(),
                insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets;
        });
        host.addView(screen.root, new android.widget.FrameLayout.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(host);
        host.requestApplyInsets();
    }
}
'''.replace('__ROOT_BG__', color_java({key: value.value for key, value in app.root.style}.get('backgroundColor', '#FFFFFFFF'))), 'user')
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
        container_margins, container_gravity = {}, {}
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
            style = {key: value.value for key, value in node.style}
            style_lines = []
            if node.capability in ('column', 'row'):
                spacing = style.get('spacing', 0)
                alignment = style.get('alignment', 'start')
                for index, child in enumerate(node.children):
                    container_margins[symbol(child.id)] = spacing if index else 0
                    container_gravity[symbol(child.id)] = alignment
            android_text_style(name, node.capability, style, style_lines)
            android_box_style(name, style, style_lines)
            builds.extend(style_lines)
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
                child_name = symbol(child.id)
                height = '1' if child.capability == 'divider' else 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT'
                width = 'android.view.ViewGroup.LayoutParams.MATCH_PARENT' if child.capability == 'divider' else 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT'
                if {key: value.value for key, value in child.style}.get('fillWidth') and child.capability != 'divider':
                    width = 'android.view.ViewGroup.LayoutParams.MATCH_PARENT'
                params = 'new android.widget.LinearLayout.LayoutParams(' + width + ', ' + height + ')'
                modifiers = []
                margin = container_margins.get(child_name, 0)
                if margin:
                    modifiers.append('params_' + child_name + '.setMargins(0, %d * dp, 0, 0);' % margin)
                gravity = container_gravity.get(child_name)
                if gravity and gravity != 'start':
                    modifiers.append('params_' + child_name + '.gravity = ' + GRAVITIES_ANDROID[gravity] + ';')
                if modifiers:
                    builds.append('android.widget.LinearLayout.LayoutParams params_' + child_name + ' = ' + params + ';')
                    builds.extend(modifiers)
                    builds.append(symbol(node.id) + '.addView(' + child_name + ', params_' + child_name + ');')
                else:
                    builds.append(symbol(node.id) + '.addView(' + child_name + ', ' + params + ');')
        body = HEADER + 'package ' + app.id + ''';
public final class AppScreen {
    public final android.view.View root;
    private final AppModel model;
    private final int dp;
    private boolean updating;
''' + '\n'.join(fields) + '''
    public AppScreen(android.app.Activity activity, AppModel model) {
        this.model = model;
        this.dp = Math.round(activity.getResources().getDisplayMetrics().density);
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
