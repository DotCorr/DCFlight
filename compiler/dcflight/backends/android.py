from html import escape
from . import Artifact, HEADER
from .common import color_java, expression, symbol, expand
from ..ir import ScalarType, Reference
from ..shared_logic import call_expression
from .android_presentation import Presentation, SPECIAL
from . import android_social


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
        _rootStyle = getattr(app.root, 'style', None)
        root_bg_color = _rootStyle.background if (_rootStyle is not None and _rootStyle.background is not None) else '#FFFFFF'
        files = {}
        presentation = Presentation(app)
        java = 'android/app/src/main/java/' + app.id.replace('.', '/') + '/'
        def put(path, content, ownership='generated'):
            files[path] = Artifact(content, ownership)
        put('android/settings.gradle', '''pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = 'App'
include ':app'
''', 'user')
        put('android/build.gradle', "plugins { id 'com.android.application' version '8.9.2' apply false }\n", 'user')
        put('android/app/build.gradle', "plugins { id 'com.android.application' }\nandroid {\n    namespace '" + app.id + "'\n        defaultConfig { applicationId '" + app.id + "'; versionCode 1; versionName '1.0' }\n    packaging { jniLibs { keepDebugSymbols += ['**/libapplogic.so'] } }\n    compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }\n}\n", 'user')
        files['android/app/build.gradle']=Artifact(files['android/app/build.gradle'].content+"\napply from: 'native-versions.gradle'\n", files['android/app/build.gradle'].ownership)
        put('android/app/src/main/AndroidManifest.xml', '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:label="''' + escape(app.name, quote=True) + '''" android:theme="@android:style/Theme.Material.Light.NoActionBar">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
    </activity>
  </application>
</manifest>
''', 'user')
        if presentation.images:
            manifest_path = 'android/app/src/main/AndroidManifest.xml'
            original = files[manifest_path]
            files[manifest_path] = Artifact(original.content.replace('  <application', '  <uses-permission android:name="android.permission.INTERNET"/>\n  <application'), original.ownership)
        put(java + 'MainActivity.java', HEADER + 'package ' + app.id + ''';
public final class MainActivity extends android.app.Activity {
    private AppScreen screen;
    @Override public void onCreate(android.os.Bundle savedState) {
        super.onCreate(savedState);
        AppModel model = new AppModel();
        screen = new AppScreen(this, model);
        android.widget.FrameLayout host = new android.widget.FrameLayout(this);
        host.setBackgroundColor(android.graphics.Color.parseColor("''' + root_bg_color + '''"));
        final int contentPadding = Math.round(''' + ('0' if getattr(app.root, 'style', None) is not None else '16') + ''' * getResources().getDisplayMetrics().density);
        if (android.os.Build.VERSION.SDK_INT < 35) {
            getWindow().setStatusBarColor(android.graphics.Color.parseColor("''' + root_bg_color + '''"));
            getWindow().setNavigationBarColor(android.graphics.Color.parseColor("''' + root_bg_color + '''"));
        }
        host.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft() + contentPadding,
                insets.getSystemWindowInsetTop() + contentPadding,
                insets.getSystemWindowInsetRight() + contentPadding,
                insets.getSystemWindowInsetBottom() + contentPadding);
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                android.view.WindowInsetsController controller = view.getWindowInsetsController();
                if (controller != null) {
                    int appearance = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                        | android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
                    controller.setSystemBarsAppearance(appearance, appearance);
                }
            } else {
                android.view.View decor = getWindow().getDecorView();
                decor.setSystemUiVisibility(decor.getSystemUiVisibility()
                    | android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                    | android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
            }
            return insets;
        });
        host.addView(screen.root, new android.widget.FrameLayout.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(host);
        host.requestApplyInsets();
    }
    @Override protected void onDestroy() {
        if (screen != null) screen.dispose();
        super.onDestroy();
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
            elif action.operation == 'call':
                body = target + ' = ' + call_expression(app, action, 'android', expression) + ';'
                if action.failure:
                    body = 'try { '+body+' } catch (SharedLogic.InputFailure error) { this.a_'+action.failure+'(); return; }'
            elif action.operation == 'set':
                body = target + ' = ' + expression(action.value, 'android').replace('model.s_', 'this.s_') + ';'
            else:
                body = 'UserActions.a_' + action.id + '(this);'
            methods.append('    public void a_' + action.id + '() { ' + body + ' }')
        put(java + 'AppModel.java', HEADER + 'package ' + app.id + ';\npublic final class AppModel {\n' + state + '\n' + '\n'.join(methods) + '\n}\n')
        if android_social.supports(app):
            files.update(android_social.generate(app))
            return files
        fields, builds, updates, listeners = [], [], [], []
        container_margins, container_gravity = {}, {}
        for node in app.nodes():
            name = symbol(node.id)
            mapping = registry.get(node.capability)['targets']['android']
            fields.append('    private final ' + presentation.class_name(node, mapping) + ' ' + name + ';')
            if node.capability == 'native':
                builds.append(name + ' = UserViews.v_' + node.props()['symbol'].value + '(activity, model);')
            else:
                builds.append(presentation.construct(node, name, mapping))
            # Native platform accessibility uses text/control semantics; IDs remain stable for inspection.
            builds.append(name + '.setTag("' + node.id + '");')
            values = {key: expression(value, 'android') for key, value in node.properties}
            values['view'] = name
            if node.capability not in SPECIAL:
                updates.append(expand(mapping['update'], values))
            builds.extend(presentation.setup(node, name))
            updates.extend(presentation.updates(node, name))
            if node.action:
                listeners.append(name + '.setOnClickListener(v -> { model.a_' + node.action + '(); refresh(); });')
            if node.capability == 'toggle':
                ref = node.props()['value'].name
                listeners.append(name + '.setOnCheckedChangeListener((button, checked) -> { if (!updating) { model.s_' + ref + ' = checked; refresh(); } });')
            if node.capability in ('textField','secureField'):
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
            for index, child in enumerate(node.children):
                builds.extend(presentation.parent(node, child, index))
        body = HEADER + 'package ' + app.id + ''';
public final class AppScreen {
    public final android.view.View root;
    private final AppModel model;
    private final int dp;
    private boolean updating;
''' + '\n'.join(fields) + '\n' + presentation.declarations() + '''
    public AppScreen(android.app.Activity activity, AppModel model) {
        this.model = model;
        this.activity = activity;
        this.density = activity.getResources().getDisplayMetrics().density;
''' + '\n'.join(builds) + '\nroot = ' + symbol(app.root.id) + ';\n' + '\n'.join(presentation.root_layout()) + '\n' + '\n'.join(listeners) + '''
        root.addOnAttachStateChangeListener(new android.view.View.OnAttachStateChangeListener() {
            public void onViewAttachedToWindow(android.view.View view) {}
            public void onViewDetachedFromWindow(android.view.View view) { dispose(); }
        });
        refresh();
    }
    public void refresh() {
        updating = true;
        try {
''' + '\n'.join(updates) + '''
        } finally { updating = false; }
    }
''' + presentation.methods() + '\n}\n'
        put(java + 'AppScreen.java', body)
        files.update(presentation.resources())
        return files
