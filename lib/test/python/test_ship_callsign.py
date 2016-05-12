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
        self.assertEqual(ship_callsign('3FLZ'),      'Tropical-Islander')
        self.assertEqual(ship_callsign('5BPB3'),     'Patricia-Schulte')
        self.assertEqual(ship_callsign('5WDC'),      'Capitaine-Fearn')
        self.assertEqual(ship_callsign('9HA2479'),   'Pacific-Sun')
        self.assertEqual(ship_callsign('9V2768'),    'RTM-Wakmatha')
        self.assertEqual(ship_callsign('9V3581'),    'Maersk-Jalan')
        self.assertEqual(ship_callsign('9V9713'),    'Shengking')
        self.assertEqual(ship_callsign('9V9832'),    'Siangtan')
        self.assertEqual(ship_callsign('9VEY2'),     'Southern-Lily')
        self.assertEqual(ship_callsign('A8JM5'),     'ANL-Benalla')
        self.assertEqual(ship_callsign('A8SW3'),     'Buxlink')
        self.assertEqual(ship_callsign('C6FS9'),     'Stadacona')
        self.assertEqual(ship_callsign('DDPH'),      'Merkur-Sky')
        self.assertEqual(ship_callsign('E5WW'),      'Will-Watch')
        self.assertEqual(ship_callsign('FHZI'),      'Astrolabe')
        self.assertEqual(ship_callsign('HSB3402'),   'Xutra-Bhum')
        self.assertEqual(ship_callsign('HSB3403'),   'Wana-Bhum')
        self.assertEqual(ship_callsign('LFB13191P'), 'Santo-Rocco')
        self.assertEqual(ship_callsign('P3JM9'),     'Conti-Harmony')
        self.assertEqual(ship_callsign('PBKZ'),      'Schelde-Trader')
        self.assertEqual(ship_callsign('V2BF1'),     'Florence')
        self.assertEqual(ship_callsign('V2BJ5'),     'ANL-Yarrunga')
        self.assertEqual(ship_callsign('V2BP4'),     'Vega-Gotland')
        self.assertEqual(ship_callsign('V2CN5'),     'Sofrana-Surville')
        self.assertEqual(ship_callsign('VHGI'),      'Southern-Champion')
        self.assertEqual(ship_callsign('VHLU'),      'Austral-Leader-II')
        self.assertEqual(ship_callsign('VHW5167'),   'Sea-Flyte')
        self.assertEqual(ship_callsign('VHW6005'),   'Linnaeus')
        self.assertEqual(ship_callsign('VJQ7467'),   'Fantasea-Wonder')
        self.assertEqual(ship_callsign('VLHJ'),      'Southern-Surveyor')
        self.assertEqual(ship_callsign('VLMJ'),      'Investigator')
        self.assertEqual(ship_callsign('VLST'),      'Spirit-of-Tasmania-1')
        self.assertEqual(ship_callsign('VMQ9273'),   'Solander')
        self.assertEqual(ship_callsign('VNAA'),      'Aurora-Australis')
        self.assertEqual(ship_callsign('VNAH'),      'Portland')
        self.assertEqual(ship_callsign('VNCF'),      'Cape-Ferguson')
        self.assertEqual(ship_callsign('VNSZ'),      'Spirit-of-Tasmania-2')
        self.assertEqual(ship_callsign('VNVR'),      'Iron-Yandi')
        self.assertEqual(ship_callsign('VRCF6'),     'Santos-Express')
        self.assertEqual(ship_callsign('VRDU8'),     'OOCL-Panama')
        self.assertEqual(ship_callsign('VROB'),      'Highland-Chief')
        self.assertEqual(ship_callsign('VRUB2'),     'Chenan')
        self.assertEqual(ship_callsign('VRZN9'),     'Pacific-Celebes')
        self.assertEqual(ship_callsign('WTEE'),      'Oscar-Elton-Sette')
        self.assertEqual(ship_callsign('YJZC5'),     'Pacific-Gas')
        self.assertEqual(ship_callsign('ZM7552'),    'Kaharoa')
        self.assertEqual(ship_callsign('ZMFR'),      'Tangaroa')
        self.assertEqual(ship_callsign('ZMRE'),      'Rehua')
        self.assertEqual(ship_callsign('ZMTW'),      'Janas')

    def test_unknown_ship_name(self):
        self.assertEqual(ship_callsign('unknown'), None)

if __name__ == '__main__':
    unittest.main()
