import unittest
from dcflight.platforms.android_api import JavaValue


class AndroidTypedLiteralTests(unittest.TestCase):
    def test_exact_primitive_bounds_and_spellings(self):
        self.assertEqual('-9223372036854775808L', JavaValue.typed_literal(-2**63,'long').source())
        self.assertEqual('9223372036854775807L', JavaValue.typed_literal(2**63-1,'long').source())
        self.assertEqual('(char) 10', JavaValue.typed_literal('\n','char').source())
        self.assertEqual('(float) 1e-50d', JavaValue.typed_literal(1e-50,'float').source())
        for value, kind in [(2**63,'long'),(-129,'byte'),(32768,'short'),
                            (True,'int'),(1,'boolean'),(None,'long'),
                            ('😀','char'),('ab','char'),('\ud800','char'),
                            (float('inf'),'double'),(1e39,'float'),
                            ('1; exit();','int'),(1,'java.lang.Integer')]:
            with self.assertRaises(ValueError, msg=kind):
                JavaValue.typed_literal(value,kind)

