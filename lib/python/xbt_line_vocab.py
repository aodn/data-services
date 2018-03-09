#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Read the XBT line vocabulary from vocabs.ands.org.au

How to use:
    from xbt_line_vocab import *

    xbt_info = xbt_line_info() # simple dictionnary of all the xbt line labels
    the dict keys refer to the prefLabel
    the dict values : None if no code, otherwise the code value

author : Besnard, Laurent
"""

import urllib2
import xml.etree.ElementTree as ET


def xbt_line_info():
    """
    retrieves a dictionnary of xbt line code with their IMOS code equivalent if available
    """
    xbt_line_vocab_url     = 'https://vocabs.ands.org.au/repository/api/registry/api/resource/downloads/367/aodn_aodn-xbt-line-vocabulary_version-1-0.rdf'
    response               = urllib2.urlopen(xbt_line_vocab_url)
    html                   = response.read()
    root                   = ET.fromstring(html)
    xbt_dict = {}

    for item in root:
        if 'Description' in item.tag:
            xbt_line_code = None
            xbt_line_pref_label = None

            for val in item:
                platform_element_sublabels = val.tag

                if platform_element_sublabels is not None:
                    if 'prefLabel' in platform_element_sublabels:
                        xbt_line_pref_label = val.text
                    if 'code' in platform_element_sublabels:
                        xbt_line_code = val.text

            if xbt_line_pref_label and xbt_line_code:
                xbt_dict[xbt_line_pref_label] = xbt_line_code
            elif xbt_line_pref_label and not xbt_line_code:
                xbt_dict[xbt_line_pref_label] = None

    response.close()
    return xbt_dict
