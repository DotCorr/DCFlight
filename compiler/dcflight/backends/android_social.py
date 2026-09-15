"""Compile shared social service declarations into ordinary Android application sources."""
import json
from pathlib import Path
from html import escape
from urllib.parse import urlsplit, urlunsplit
from . import Artifact, HEADER
from .android_presentation import color, PATHS
from ..ir import Theme

FEATURES = frozenset({'camera', 'inbox', 'stories', 'friendMap', 'account'})
MAPLIBRE_COORDINATE = 'org.maplibre.gl:android-sdk-opengl:12.3.1'


def supports(app):
    return app.service is not None and any(node.capability in FEATURES for node in app.nodes())


def generate(app):
    theme = app.theme or Theme()
    tabs = [node for node in app.nodes() if node.capability == 'tab']
    if not tabs:
        raise ValueError('Android social features require a tabs composition')
    base = app.service.base_url.rstrip('/')
    parts = urlsplit(base)
    if app.service.development and parts.hostname in {'localhost', '127.0.0.1'}:
        base = urlunsplit((parts.scheme, '10.0.2.2' + (':' + str(parts.port) if parts.port else ''), parts.path, '', ''))
    replacements = {'__PACKAGE__': app.id, '__BASE__': json.dumps(base), '__NAME__': json.dumps(app.name),
        '__TITLES__': 'new String[]{' + ','.join(json.dumps(tab.props()['title'].value) for tab in tabs) + '}',
        '__FEATURES__': 'new String[]{' + ','.join(json.dumps(tab.children[0].capability) for tab in tabs) + '}',
        '__ICONS__': 'new int[]{' + ','.join('R.drawable.app_icon_' + tab.props()['icon'].value for tab in tabs) + '}',
        '__RADIUS__': str(theme.radius), '__PADDING__': str(theme.padding)}
    for name in ('accent', 'background', 'surface', 'text', 'muted', 'danger'):
        replacements['__' + name.upper() + '__'] = color(getattr(theme, name))
    files = {}
    java = 'android/app/src/main/java/' + app.id.replace('.', '/') + '/'
    for template in sorted((Path(__file__).parent / 'templates' / 'android_social').glob('*.java')):
        source = template.read_text()
        for key, value in replacements.items():
            source = source.replace(key, value)
        files[java + template.name] = Artifact(HEADER + source)
    files[java + 'MainActivity.java'] = Artifact(HEADER + 'package ' + app.id + ';\npublic final class MainActivity extends SocialActivity {}\n', 'user')
    permissions = ['INTERNET', 'CAMERA', 'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION']
    manifest = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n' + ''.join('  <uses-permission android:name="android.permission.' + p + '"/>\n' for p in permissions)
    manifest += '  <uses-feature android:name="android.hardware.camera.any" android:required="false"/>\n'
    manifest += '  <application android:allowBackup="false" android:label="' + escape(app.name, quote=True) + '" android:theme="@android:style/Theme.Material.Light.NoActionBar"' + (' android:networkSecurityConfig="@xml/network_security_config"' if app.service.development else '') + '>\n'
    manifest += '    <activity android:name=".MainActivity" android:exported="true" android:windowSoftInputMode="adjustResize"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity>\n  </application>\n</manifest>\n'
    files['android/app/src/main/AndroidManifest.xml'] = Artifact(manifest, 'user')
    if app.service.development:
        files['android/app/src/main/res/xml/network_security_config.xml'] = Artifact('<network-security-config><base-config cleartextTrafficPermitted="false"/><domain-config cleartextTrafficPermitted="true"><domain>10.0.2.2</domain></domain-config></network-security-config>\n')
    for name, path in PATHS.items():
        files['android/app/src/main/res/drawable/app_icon_' + name + '.xml'] = Artifact('<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:strokeColor="#18191C" android:strokeWidth="1.8" android:strokeLineCap="round" android:strokeLineJoin="round" android:fillColor="@android:color/transparent" android:pathData="' + path + '"/></vector>\n')
    return files
