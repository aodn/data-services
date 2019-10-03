#!/usr/bin/env python
"""
Script to facilitate the test of the compliance checker with expected results.

The script reads a json config file [CONFIG_FILE], downloads the different NetCDF files to test.
The compliance checker will be run on each of those NetCDF with the different options needed (criteria, skip_checks,
expected failures, expected success)

The results will be output to a temporary file (see outfile_path variable) in a similar structure to the CONFIG_FILE
author: Besnard, Laurent
"""
import json
import os
import tempfile
from urllib.request import urlretrieve

from util import pass_netcdf_checker

TEST_ROOT = os.path.join(os.path.dirname(__file__))

CONFIG_FILE = os.path.join(TEST_ROOT, "compliance_checker_imos_files_config.json")

with open(CONFIG_FILE, 'r') as f:
    compliance_config = json.load(f)

for collection in compliance_config:
    print("Running test suite for: {collection}".format(collection=collection))

    for sub_collection in compliance_config[collection].items():
        file_url = sub_collection[1]['path'][0]
        tempfile_obj = tempfile.mkstemp()
        tempfile_path = tempfile_obj[1]
        urlretrieve(file_url, tempfile_path)

        check_success_tests = sub_collection[1]['check_params']['checks_success']
        check_fail_tests = sub_collection[1]['check_params']['checks_fail']

        criteria = sub_collection[1]['check_params']['criteria']
        if criteria == []:
            criteria = "normal"
        else:
            criteria = criteria[0]

        skip_checks = sub_collection[1]['check_params']['skip_checks']

        # running checks which should succeed
        compliance_config[collection][sub_collection[0]]['checks_success_tests_results'] = {}
        for test in check_success_tests:
            try:
                res = pass_netcdf_checker(tempfile_path, tests=[test], criteria=criteria, skip_checks=skip_checks)
                compliance_config[collection][sub_collection[0]]['checks_success_tests_results'].setdefault(test, []).append(res)
            except ValueError:
                pass

        # running checks which should fail
        compliance_config[collection][sub_collection[0]]['checks_fail_tests_results'] = {}
        for test in check_fail_tests:
            try:
                res = not(pass_netcdf_checker(tempfile_path, tests=[test], criteria=criteria, skip_checks=skip_checks))
                compliance_config[collection][sub_collection[0]]['checks_fail_tests_results'].setdefault(test, []).append(res)
            except ValueError:
                pass

# write to a json file (similar structure to input file)
tempdir = tempfile.gettempdir()
outfile_path = os.path.join(tempdir, 'compliance_checker_results.json')
with open(outfile_path, 'w') as outfile:
    json.dump(compliance_config, outfile)

print("outputs results can be found at: {outfile_path}".format(outfile_path=outfile_path))
