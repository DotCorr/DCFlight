import unittest
from dcflight.presentation import ICONS
from dcflight.registry import Registry
from dcflight.backends.ios_presentation import ICONS as IOS_ICONS
from dcflight.backends.android_presentation import PATHS as ANDROID_PATHS
from dcflight.validate import lower, Diagnostic


class IconSetTests(unittest.TestCase):
    def test_every_icon_literal_has_native_mappings_on_both_platforms(self):
        for name in ICONS:
            with self.subTest(icon=name):
                self.assertIn(name, IOS_ICONS, 'missing SF Symbol mapping: ' + name)
                self.assertIn(name, ANDROID_PATHS, 'missing Android vector path: ' + name)

    def test_native_mappings_carry_only_supported_literals(self):
        self.assertEqual(set(IOS_ICONS), set(ICONS))
        self.assertEqual(set(ANDROID_PATHS), set(ICONS))

    def test_android_vector_paths_are_well_formed(self):
        allowed = set('MLHVQCSAZmlhvqcsaz') | set('0123456789,. -')
        for name, path in ANDROID_PATHS.items():
            with self.subTest(icon=name):
                self.assertTrue(path and path.count('M') >= 1, 'empty vector path: ' + name)
                self.assertTrue(set(path) <= allowed, 'malformed vector path characters: ' + name)
                self.assertFalse(path.lstrip()[0] not in 'Mm', 'vector path must start with moveto: ' + name)

    def _document(self, icon):
        return {'version': 2, 'id': 'com.example.icons', 'name': 'Icons',
                'root': {'id': 'tabs', 'type': 'tabs', 'props': {}, 'children': [
                    {'id': 'tab', 'type': 'tab', 'props': {'title': 'Home', 'icon': icon},
                     'children': [{'id': 'stack', 'type': 'navigationStack', 'props': {'initialRoute': 'home'}}]}]},
                'routes': [{'id': 'home', 'title': 'Home',
                            'body': {'id': 'hint', 'type': 'icon', 'props': {'name': icon}}}]}

    def test_new_common_icons_validate_as_tab_and_icon_node(self):
        for name in ('inbox', 'home', 'mail', 'calendar', 'star', 'flag', 'clock', 'folder'):
            with self.subTest(icon=name):
                lower(self._document(name), Registry())

    def test_unknown_icon_literal_is_rejected_everywhere(self):
        with self.assertRaisesRegex(Diagnostic, 'tab title/icon require supported literal values'):
            lower(self._document('cupcake'), Registry())


if __name__ == '__main__':
    unittest.main()
