#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import re

def remove_creation_date_from_filename(netcdf_file_path):
    return re.sub('_C-.*.nc$', '.nc', netcdf_file_path)

def create_file_hierarchy(file_path):
    bodbaw_dir = os.path.join('SRS', 'OC', 'BODBAW')

    filename = os.path.basename(remove_creation_date_from_filename(file_path))
    m = re.search('^IMOS_SRS-OC-BODBAW_X_([0-9]+T[0-9]+)Z_(.*)-(suspended_matter|pigment|absorption.*)_END-([0-9]+T[0-9]+)Z\.(nc|csv|png)$', filename)
    if m is None:
        return None

    product_type = m.group(3)
    if 'absorption' in product_type:
        product_type = 'absorption'

    cruise_id            = m.group(2)
    year                 = int(m.group(1)[0:4])
    relative_netcdf_path = os.path.join(bodbaw_dir, '%d_cruise-%s' %
                                        (year, cruise_id), product_type, filename)

    return relative_netcdf_path

if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = create_file_hierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
