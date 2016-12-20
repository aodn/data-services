#!/usr/bin/env python
"""
Unit tests for ship_callsign functions

author: Besnard, Laurent
"""

import unittest

from ship_callsign import ship_callsign


class TestShipCallSign(unittest.TestCase):

    def test_ship_name(self):
        self.assertEqual(ship_callsign('3FLZ'), 'Tropical-Islander')

    def test_unknown_ship_name(self):
        self.assertEqual(ship_callsign('unknown'), None)


if __name__ == '__main__':
    unittest.main()
