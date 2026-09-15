"""Regressions for the native light-theme Android activity template."""
import json
from pathlib import Path
import unittest
from dcflight.backends.android import Android
from dcflight.registry import Registry
from dcflight.validate import lower


class AndroidWindowTests(unittest.TestCase):
    def setUp(self):
        source = Path(__file__).resolve().parents[1] / 'dcflight/data/starter.json'
        app = lower(json.loads(source.read_text()), Registry())
        self.artifact = Android().generate(app, Registry())['android/app/src/main/java/' + app.id.replace('.', '/') + '/MainActivity.java']

    def test_light_system_icons_use_native_guarded_apis(self):
        source = self.artifact.content
        self.assertIn('Build.VERSION.SDK_INT >= 30', source)
        self.assertIn('APPEARANCE_LIGHT_STATUS_BARS', source)
        self.assertIn('APPEARANCE_LIGHT_NAVIGATION_BARS', source)
        self.assertIn('controller.setSystemBarsAppearance(appearance, appearance)', source)
        self.assertIn('decor.getSystemUiVisibility()', source)
        self.assertIn('SYSTEM_UI_FLAG_LIGHT_STATUS_BAR', source)
        self.assertIn('SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR', source)
        self.assertIn('Build.VERSION.SDK_INT < 35', source)
        self.assertNotIn('androidx', source)
        self.assertEqual('user', self.artifact.ownership)

    def test_content_spacing_is_added_to_all_system_insets(self):
        source = self.artifact.content
        self.assertIn('Math.round(16 * getResources().getDisplayMetrics().density)', source)
        for edge in ('Left', 'Top', 'Right', 'Bottom'):
            self.assertIn('insets.getSystemWindowInset' + edge + '() + contentPadding', source)
        self.assertIn('host.requestApplyInsets()', source)
        self.assertIn('return insets;', source)
        self.assertNotIn('view.getPadding', source)  # Reapplying insets must not accumulate padding.


if __name__ == '__main__': unittest.main()
