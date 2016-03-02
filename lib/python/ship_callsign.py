#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Reads the ship_callsign text file in the same directory and returns a
dictionnary of callsign and vessel names.
Used for SOOP

How to use:
    import os, sys
    sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
    from python.ship_callsign import ship_callsign_list

author : Besnard, Laurent
"""

import os
from ConfigParser import SafeConfigParser


def _call_parser(conf_file):
    parser             = SafeConfigParser()
    parser.optionxform = str  # to preserve case
    parser.read(conf_file)
    return parser


def ship_callsign_list():
    """
    returns a dictionnary of all ship callsigns and vessel names equivalence as
    found in the ship_callsign file
    """
    function_dir       = os.path.dirname(os.path.realpath(__file__))
    ship_callsign_file = os.path.join(function_dir, 'ship_callsign')

    parser             = _call_parser(ship_callsign_file)
    ship_callsign      = dict(parser.items('ship_callsign'))

    return ship_callsign


def ship_callsign(callsign):
    """
    returns the vessel name of a specific callsign
    returns none if the vessel name does not exist
    """
    callsigns = ship_callsign_list()
    if callsign in callsigns.keys():
        return callsigns[callsign]
    else:
        return None
