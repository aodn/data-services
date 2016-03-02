#!/usr/bin/env python
"""
Unit tests for ship_callsign functions

author: Besnard, Laurent
"""

import unittest
import os
import sys

LIB_DIR = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..'))
sys.path.insert(0, LIB_DIR)

from python.ship_callsign import ship_callsign

class TestShipCallSign(unittest.TestCase):

    def test_ship_name(self):
        self.assertEqual(ship_callsign('FHZI'), 'Astrolabe')

    def test_unknown_ship_name(self):
        self.assertEqual(ship_callsign('unknown'), None)

if __name__ == '__main__':
    unittest.main()
