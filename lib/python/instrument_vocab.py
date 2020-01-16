"""
List the instruments categories and their related instrument names
from poolparty instrument vocab

How to use:
    from instrument_vocab import *

    save_instrument_list_to_csv('/tmp/output_csv_path')  # will save instrument list to a csv file
    instrument_cat()  # create a dict of instrument categories and instrument names

author : Besnard, Laurent
"""

import urllib2
import os
import xml.etree.ElementTree as ET


def instrument_name_uris():
    """
    retrieves a list of instrument categories and their topConceptOf url type which
    defines their category
    """
    platform_cat_vocab_url = 'https://vocabs.ands.org.au/registry/api/resource/downloads/126/aodn_aodn-instrument-vocabulary_version-2-1.rdf'
    response               = urllib2.urlopen(platform_cat_vocab_url)
    html                   = response.read()
    root                   = ET.fromstring(html)
    instrument_cat_list      = {}

    for item in root:
        is_top_concept = False
        if 'Description' in item.tag:
            platform_cat = None

            for val in item:
                instrument_element_sublabel = val.tag

                # handle more than 1 url match per category of platform
                if instrument_element_sublabel is not None:
                    if 'prefLabel' in instrument_element_sublabel:
                        platform_cat = val.text

                    if 'topConceptOf' in instrument_element_sublabel:
                        is_top_concept = True

                    instrument_uri = item.items()[0][1]

            if platform_cat is not None and not is_top_concept:
                instrument_cat_list[instrument_uri] = platform_cat

    response.close()
    return instrument_cat_list


def instrument_cat():
    """
    retrieves a list of instrument categories and their relative instrument names
    into a dictionary
    """
    instrument_cat_vocab_url = 'https://vocabs.ands.org.au/registry/api/resource/downloads/126/aodn_aodn-instrument-vocabulary_version-2-1.rdf'
    response               = urllib2.urlopen(instrument_cat_vocab_url)
    html                   = response.read()
    root                   = ET.fromstring(html)
    instrument_cat_list    = {}

    instrument_name_uris_dic = instrument_name_uris()

    for item in root:
        if 'Description' in item.tag:
            instrument_cat = None
            is_top_concept = False
            instrument_sub_level = []

            for val in item:
                instrument_element_sublabel = val.tag

                # handle more than 1 url match per category of platform
                if instrument_element_sublabel is not None:
                    if 'topConceptOf' in instrument_element_sublabel:
                        is_top_concept = True

                    if 'prefLabel' in instrument_element_sublabel:
                        instrument_cat = val.text

                    if 'narrower' in instrument_element_sublabel:
                        instrument_sub_level.append(instrument_name_uris_dic[val.attrib.values()[0]])

            if instrument_cat is not None and is_top_concept:
                instrument_cat_list[instrument_cat] = instrument_sub_level

    response.close()
    return instrument_cat_list


def save_instrument_list_to_csv(output_path_dir):
    """
    save instrument information from instrument_cat() into a csv file
    """
    mydict = instrument_cat()

    if not os.path.exists(output_path_dir):
        os.makedirs(output_path_dir)

    with open(os.path.join(output_path_dir, 'instrument_vocab.csv'), 'w') as the_file:
        for key, val in sorted(mydict.iteritems()):
            if len(val) > 1:
                the_file.write("%s, %s\n" % (key, val[0]))
                for i in range(1, len(val)):
                    the_file.write(", %s\n" % (val[i]))
            else:
                the_file.write("%s, %s\n" % (key, val))
