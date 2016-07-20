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
    m = re.search('^IMOS_SRS-OC-LJCO_(.*)_(.*)_SRC_FV(.*)\.nc$',
                  netcdf_filename)

    if m is None:
        return None

    product_type_ls     = re.compile('ACS|EcoTriplet|BB9|HyperOCR|WQM')
    product_type_netcdf = product_type_ls.findall(netcdf_filename)

    product_temp_ls     = re.compile('hourly|daily|monthly')
    product_temp_netcdf = product_temp_ls.findall(netcdf_filename)

    if product_type_netcdf == [] or product_temp_netcdf == []:
        return None
    product_dir = '%s-%s' % (product_type_netcdf[0], product_temp_netcdf[0])

    year = int(m.group(2)[0:4])
    if 'hourly' in product_dir:
        month                = int(m.group(2)[4:6])
        day                  = int(m.group(2)[6:8])
        relative_netcdf_path = os.path.join(ljco_wqm_dir, product_dir, '%d' % year,
                                            '%02d' % month, '%02d' % day, netcdf_filename)
    else:
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
