#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import re


def remove_creation_date_from_filename(netcdf_file_path):
    return re.sub('_C-.*.nc$', '.nc', netcdf_file_path)

def create_file_hierarchy(netcdf_file_path):
    ljco_wqm_dir = os.path.join('SRS', 'OC', 'LJCO')

    netcdf_filename  = os.path.basename(netcdf_file_path)
    netcdf_filename  = remove_creation_date_from_filename(netcdf_filename)

    # looking for product_name
    m = re.search('^IMOS_SRS-OC-LJCO_KOSTUZ_(.*)_SRC_FV(.*)\.nc$',
                  netcdf_filename)
    if m is None:
        return None

    if m.group(2) == '01_WQM-hourly':
        product_dir = 'WQM-hourly'
    elif m.group(2) == '01_Weather-monthly':
        product_dir = 'Weather-monthly'
    elif m.group(2) == '02_WQM-daily':
        product_dir = 'WQM-daily'
    else:
        return None

    year                 = int(m.group(1)[0:4])
    relative_netcdf_path = os.path.join(ljco_wqm_dir, product_dir, str(year),
                                        netcdf_filename)

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
