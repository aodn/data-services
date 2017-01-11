#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Code to generate the talend databags used by the generic harvester
generate_ghrsst_databags_chef.py > chef/data_bags/talend/srs_ghrsst_gridded.json
"""

str = """{
    "id": "srs_ghrsst_gridded",
    "artifact_filename": "GENERIC_TIMESTEP_harvester_Latest.zip",
    "params": {
        "Destination_Schema": "generic_timestep",
        "Destination_Login": "generic_timestep",
        "Destination_Password": "generic_timestep"
    },
    "events": ["""

# create databags for products with different sat numbers

sat_name_l3u = ['n09', 'n11', 'n12', 'n14', 'n15', 'n16', 'n17', 'n18', 'n19']
sat_name_l3c = ['n11', 'n12', 'n14', 'n15', 'n16', 'n17', 'n18', 'n19']

prods                = {}
prods['L3U']         = 'l3u'
prods['L3U-S']       = 'l3u_S'
prods['L3C-1d/ngt']  = 'l3c_1d_ngt'
prods['L3C-1d/day']  = 'l3c_1d_day'
prods['L3C-1dS/ngt'] = 'l3c_1d_S_ngt'
prods['L3C-1dS/day'] = 'l3c_1d_S_day'
prods['L3C-3d/ngt']  = 'l3c_3d_ngt'
prods['L3C-3d/day']  = 'l3c_3d_day'


for prod in prods.keys():
    if 'L3U' in prod:
        sat_names = sat_name_l3u
    elif 'L3C' in prod:
        sat_names = sat_name_l3c

    for sat_name in sat_names:
        str = """%s
        {
        "regex": [
            "^IMOS/SRS/SST/ghrsst/%s/%s.*\\\\.nc$"
        ],
        "extra_params": {
            "collection": "srs_ghrsst_%s_%s"
        }
        },
        """ % (str, prod, sat_name, prods[prod], sat_name)


# create databags for products WITHOUT different sat numbers
prods               = {}
prods['L3S-1d/ngt'] = 'l3s_1d_ngt'
prods['L3S-1d/day'] = 'l3s_1d_day'
prods['L3S-1d/dn']  = 'l3s_1d_dn'

prods['L3S-3d/ngt'] = 'l3s_3d_ngt'
prods['L3S-3d/day'] = 'l3s_3d_day'
prods['L3S-3d/dn']  = 'l3s_3d_dn'

prods['L3S-6d/ngt'] = 'l3s_6d_ngt'
prods['L3S-6d/day'] = 'l3s_6d_day'
prods['L3S-6d/dn']  = 'l3s_6d_dn'

prods['L3S-14d/ngt'] = 'l3s_14d_ngt'
prods['L3S-14d/day'] = 'l3s_14d_day'
prods['L3S-14d/dn']  = 'l3s_14d_dn'

prods['L3S-1m/ngt'] = 'l3s_1m_ngt'
prods['L3S-1m/day'] = 'l3s_1m_day'
prods['L3S-1m/dn']  = 'l3s_1m_dn'

prods['L3S-1mS/dn']  = 'l3s_1mS_dn'
prods['L3S-1dS/dn']  = 'l3s_1dS_dn'

prods['L3P/14d']  = 'l3p_14d'

for prod in prods.keys():
    str = """%s
        {
        "regex": [
            "^IMOS/SRS/SST/ghrsst/%s.*\\\\.nc$"
        ],
        "extra_params": {
            "collection": "srs_ghrsst_%s"
        }
        },
        """ % (str, prod, prods[prod])

str_ending = """
    ]
}"""
print "%s%s" % (str[:-10], str_ending)
