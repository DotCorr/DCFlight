import unittest
from dcflight.backends.ios_presentation import render, color
from dcflight.ir import Node, Style, Motion, Literal, Reference, ScalarType


class IOSPresentationTests(unittest.TestCase):
    def test_disabled_authored_control_has_shared_visual_feedback(self):
        node=Node('capture','button',(),(),style=Style(background='#FFDD33'),enabled_when=Reference('ready',ScalarType.BOOL))
        body=render(node,'Button("Capture") {}').body
        self.assertIn('.disabled(!(model.s_ready))',body)
        self.assertIn('.opacity(model.s_ready ? 1 : 0.45)',body)
    def test_legacy_body_unchanged(self):
        self.assertEqual(render(Node('x','text',(),()),'Text("old")').body,'Text("old")')

    def test_rgba_order_and_outer_size(self):
        node=Node('x','text',(),(),style=Style(padding=8,width=120,background='#11223380',radius=4,border_color='#000000',border_width=1))
        body=render(node,'Text("hello")').body
        self.assertLess(body.index('.padding'),body.index('.frame'))
        self.assertLess(body.index('.frame'),body.index('.background'))
        self.assertIn('opacity: 0.5019607843',body)
        self.assertIn('strokeBorder',body)
        with self.assertRaises(ValueError): color('red); bad()')

    def test_omitted_and_empty_container_styles_have_identical_defaults(self):
        from dataclasses import replace
        from dcflight.backends.android_routed import AndroidRouted
        child=Node('label','text',(('text',Literal('Content',ScalarType.STRING)),),())
        for kind,swift,alignment in [('row','HStack','top'),('column','VStack','leading'),('card','VStack','leading')]:
            with self.subTest(kind=kind):
                node=Node('container',kind,(),(child,))
                empty=replace(node,style=Style())
                before=render(node,'platform default').body
                self.assertEqual(before,render(empty,'platform default').body)
                self.assertIn(swift+'(alignment: .'+alignment+', spacing: 0)',before)
                backend=AndroidRouted()
                self.assertEqual(backend.node(node),backend.node(empty))
                self.assertIn('Arrangement.spacedBy(0.dp)',backend.node(node))

    def test_styled_button_geometry_is_inside_native_label(self):
        from dcflight.backends.ios_presentation import render_button
        node=Node('button','button',(('text',Literal('Continue',ScalarType.STRING)),),(),
                  style=Style(width=220,height=56,padding=12,radius=14,background='#FFDD33',align='center'),
                  enabled_when=Reference('ready',ScalarType.BOOL),
                  visible_when=Reference('show',ScalarType.BOOL),motion=Motion('fade',180))
        result=render_button(node,'{}')
        body=result.body
        label_end=body.index('}.buttonStyle(.plain)')
        for fragment in ['.padding(12)', 'width: 220, height: 56', '.background(', '.contentShape(RoundedRectangle(cornerRadius: 14))']:
            self.assertLess(body.index(fragment),label_end)
        self.assertGreater(body.index('.disabled('),label_end)
        self.assertEqual(1,body.count('.disabled('))
        self.assertEqual(1,body.count('if model.s_show'))
        self.assertIn('accessibilityReduceMotion',result.declarations)
        self.assertIn('.multilineTextAlignment(.center)',body)

    def test_explicit_cross_axis_and_gap(self):
        row=Node('x','row',(),(),style=Style(gap=12,align='end'))
        column=Node('y','column',(),(),style=Style(gap=0,align='center'))
        self.assertIn('HStack(alignment: .bottom, spacing: 12)',render(row,'').body)
        self.assertIn('VStack(alignment: .center, spacing: 0)',render(column,'').body)

    def test_visibility_transition_honors_reduce_motion(self):
        node=Node('x','text',(),(),motion=Motion('slide',180),visible_when=Reference('show',ScalarType.BOOL))
        result=render(node,'Text("hello")')
        self.assertIn('accessibilityReduceMotion',result.declarations)
        self.assertIn('if model.s_show',result.body)
        self.assertIn('.offset(y: 16).combined(with: .opacity)',result.body)
        self.assertIn('reduceMotion ? nil',result.body)

    def test_image_has_native_loading_and_failure_branches(self):
        node=Node('x','image',(('source',Literal('https://example.com/photo.png',ScalarType.STRING)),),())
        body=render(node,'').body
        self.assertIn('AsyncImage',body)
        self.assertIn('case .failure',body)
        self.assertIn('== "https"',body)
        self.assertIn('hasPrefix("asset:")',body)

if __name__=='__main__': unittest.main()
