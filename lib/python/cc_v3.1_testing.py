#!/usr/bin/env python
# -*- coding: utf-8 -*-
""" This script was done to quickly generate a summary of the current state of
success and failure of tests on netcdf files with the latest version of the IOOS
compliance checker v3.1 .
Files to be tested on are currently in $WIP_DIR/checker3_testing/ on AWS10

./cc_v3.1_testing.py $WIP_DIR/checker3_testing/ >> checker3_result.csv ; done

"""

import csv
import os
import sys

from util import pass_netcdf_checker


def read_facility_csv(csv_file_path):
    reader = csv.DictReader(open(csv_file_path))
    result = {}
    for row in reader:
        result[row['JSON watch.d']] = row['check']

    return result


def list_nc_files(root_path):
    file_list = []
    for root, dirs, files in os.walk(root_path):
        for name in files:
            if name.endswith((".nc")):
                file_list.append(os.path.abspath(os.path.join(root_path, root, name)))
    return file_list


def list_nc_checks_to_perform(netcdf_file_path, facility_csv_file_path):
    facility_checks = read_facility_csv(facility_csv_file_path)
    file_checks     = facility_checks[os.path.basename(os.path.dirname(netcdf_file_path))]

    if file_checks == "NO CHECK":
        return []

    return file_checks.split()


def testing(netcdf_file_path, facility_csv_file_path):
    tests = list_nc_checks_to_perform(netcdf_file_path, facility_csv_file_path)
    facility = os.path.basename(os.path.dirname(netcdf_file_path))
    if tests == []:
        return '%s,%s,%s' % (netcdf_file_path, 'no check to perform', facility)

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
    # read path where testing data is from command line

    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    root_path    = sys.argv[1]
    nc_file_list = list_nc_files(root_path)
    for f in nc_file_list:
        print testing(f, os.path.join(root_path, 'facility_checks.csv'))
