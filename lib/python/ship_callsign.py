#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Reads the ship_callsign from platform vocab and returns a dictionnary of
callsign and vessel names.
Used for SOOP
How to use:
    from ship_callsign import ship_callsign_list

    ship_callsign_list()
    ship_callsign('VRDU8')

author : Besnard, Laurent
"""

from platform_code_vocab import platform_altlabels_per_preflabel


def ship_callsign_list():
    """
    renaming of platform_code_vocab function and create exceptions for
    Astrolabe vessel, and others if required
    Vessel names have a '-' instead of blank space for the folder structure
    """
    platform_codes = platform_altlabels_per_preflabel('Vessel')
    platform_codes = {key: item.replace(' ', '-') for key, item in platform_codes.items()}

    if 'FHZI' in platform_codes.keys():
        platform_codes['FHZI'] = 'Astrolabe'

    if 'FASB' in platform_codes.keys():
        platform_codes['FASB'] = 'Astrolabe'

    return platform_codes

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
