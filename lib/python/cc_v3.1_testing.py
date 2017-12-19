#!/usr/bin/env python
# -*- coding: utf-8 -*-
""" This script was done to quickly generate a summary of the current state of
success and failure of tests on netcdf files with the latest version of the IOOS
compliance checker v3.1 . This script can be used as part of a bash loop to test
NetCDF files and create a CSV output such as:
for f in `find . -type f -iname '*.nc'`; do ./cc_v3.1_testing.py $f >> checker3_result.csv ; done

The current selection of files is available on AWS10, under $WIP_DIR/checker
"""

import re
import sys

from util import pass_netcdf_checker
from netCDF4 import Dataset


def list_nc_checks_to_perform(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, 'r', format='NETCDF4')
    if hasattr(netcdf_file_obj, 'Conventions'):
        conventions     = netcdf_file_obj.Conventions
    else:
        return []

    tests = []
    if 'IMOS-1.3' in conventions:
        tests.append('imos:1.3')
    if 'IMOS-1.4' in conventions:
        tests.append('imos:1.4')
    if 'CF-1.6' in conventions:
        tests.append('cf:1.6')

    return tests


def get_sub_facility_name(netcdf_file_path):
    m = re.search('IMOS_(.*?)_(.*)\.nc$', netcdf_file_path)
    if hasattr(m, 'group'):
        return m.group(1)
    else:
        exit(0)


def testing(netcdf_file_path):
    tests = list_nc_checks_to_perform(netcdf_file_path)
    facility = get_sub_facility_name(netcdf_file_path)
    if tests == []:
        return '%s,%s,%s' % (netcdf_file_path, 'no Conventions att in NC', facility)

    res_str = ''
    for test in tests:
        res = pass_netcdf_checker(netcdf_file_path, tests=[test])
        if res_str == '':
            res_str = '%s,%s' % (test, res)
        else:
            res_str = '%s,%s,%s' % (res_str, test, res)

    res_str = '%s,,%s,%s' % (netcdf_file_path, facility, res_str)
    return res_str


if __name__  == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    print testing(sys.argv[1])
