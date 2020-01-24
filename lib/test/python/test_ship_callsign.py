#!/usr/bin/env python3
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

    def test_ship_old_new_same_callsign(self):
        " test when a new vessel has a different callsign but same name"
        self.assertEqual(ship_callsign('VROJ8'), 'Highland-Chief')
        self.assertEqual(ship_callsign('VROB'), 'Highland-Chief')

    def test_ship_astrolabe(self):
        self.assertEqual(ship_callsign('FHZI'), 'Astrolabe')
        self.assertEqual(ship_callsign('FASB'), 'Astrolabe')


if __name__ == '__main__':
    unittest.main()
