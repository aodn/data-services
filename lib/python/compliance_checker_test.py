#!/usr/bin/env python
"""
Script to facilitate the test of the compliance checker across a selection of IMOS/AODN NetCDF files. This helps making
sure the upgrade to a new version of the imos plugin/ioos compliance checker doesn't make files previously passing the
checker not passing it anymore.

The different checker suites tests are
cf:1.6
imos:1.4
imos:1.3
ghrsst:latest

The script reads a json config file [CONFIG_FILE]. This config file lists for each NetCDF to test:
 - The path of the NetCDF on the imos s3 bucket
 - checks which should pass (checks_success)
 - criteria to apply (normal, lenient ... default is normal)
 - checks expected to fail (checks_fail)
 - checks to skip (skip_checks" such as "check_convention_globals")

Each file will be downloaded in a temporary folder. The compliance checker will be run on each of those NetCDF.

The results will be output to a temporary directory (see outfile_path variable):
* a json file with a similar structure to the CONFIG_FILE containing the different results
* if some tests fail, the compliance checker output files will be saved in the same output directory

If all test succeeded, the string 'False' should not exist in the output json file. If "False"
is to be found, this means a test didn't output the required result.

author: Besnard, Laurent
"""
import json
import os
import tempfile

import cf_units
import compliance_checker
from six.moves.urllib.request import urlretrieve

from util import pass_netcdf_checker

TEST_ROOT = os.path.join(os.path.dirname(__file__))
CONFIG_FILE = os.path.join(TEST_ROOT, "compliance_checker_imos_files_config.json")
OUTPUT_DIR = tempfile.mkdtemp(prefix='compliance_checker_testing_results_')

with open(CONFIG_FILE, 'r') as f:
    compliance_config = json.load(f)

print("compliance checker {cc_version}\ncf units {cf_version}".format(cc_version=compliance_checker.__version__,
                                                                      cf_version=cf_units.__version__))

# collection is equivalent to a facility/sub-facility in the json file
for collection in compliance_config:
    print("Running test suite for: {collection}".format(collection=collection))

    for sub_collection in compliance_config[collection].items():
        file_url = sub_collection[1]['path'][0]
        tempfile_obj = tempfile.mkstemp()
        tempfile_path = tempfile_obj[1]  # path of the downloaded NetCDF
        urlretrieve(file_url, tempfile_path)

        check_success_tests = sub_collection[1]['check_params']['checks_success']
        check_fail_tests = sub_collection[1]['check_params']['checks_fail']

        criteria = sub_collection[1]['check_params']['criteria']

        # handling default parameter for criteria
        if criteria == []:
            criteria = "normal"
        else:
            criteria = criteria[0]

        skip_checks = sub_collection[1]['check_params']['skip_checks']

        """ running checks which should succeed """
        compliance_config[collection][sub_collection[0]]['checks_success_tests_results'] = {}
        for test in check_success_tests:
            try:
                res, keep_outfile_path = pass_netcdf_checker(tempfile_path, tests=[test], criteria=criteria,
                                                             skip_checks=skip_checks, keep_outfile=True,
                                                             output_format='text')
            except ValueError:
                print("compliance checker failed for \"{test}\" applied to {netcdf}".format(
                    test=test,
                    netcdf=os.path.basename(file_url)))
                res = False

            """ In the case the test failed, the compliance output file is saved and moved to OUTPUT_DIR """
            if res == False:
                err_filename = '{filename}_error_results.txt'.format(filename=os.path.basename(file_url))
                compliance_config[collection][sub_collection[0]]['checks_success_tests_results'].\
                    setdefault('{test}_failure_filename'.format(test=test), []).append(err_filename)
                os.rename(keep_outfile_path, os.path.join(OUTPUT_DIR, err_filename))
            else:
                os.remove(keep_outfile_path)

            # adding test results to json
            compliance_config[collection][sub_collection[0]]['checks_success_tests_results'].\
                setdefault(test, []).append(res)

        """ running checks which should fail """
        compliance_config[collection][sub_collection[0]]['checks_fail_tests_results'] = {}
        for test in check_fail_tests:
            try:
                res, keep_outfile_path = pass_netcdf_checker(tempfile_path, tests=[test], criteria=criteria,
                                                             skip_checks=skip_checks, keep_outfile=True,
                                                             output_format='text')
                res = not(res) # this is an expected test to fail. So we set it as True if the test failed
            except ValueError:
                print("compliance checker failed for \"{test}\" applied to {netcdf}".format(
                    test=test,
                    netcdf=os.path.basename(file_url)))
                res = False

            """ In the case the test failed, the compliance output file is saved and moved to OUTPUT_DIR """
            if res == False:
                err_filename = '{filename}_error_results.txt'.format(filename=os.path.basename(file_url))
                compliance_config[collection][sub_collection[0]]['checks_fail_tests_results'].\
                    setdefault('{test}_failure_filename'.format(test=test), []).append(err_filename)
                os.rename(keep_outfile_path, os.path.join(OUTPUT_DIR, err_filename))
            else:
                os.remove(keep_outfile_path)
            # adding test results to json
            compliance_config[collection][sub_collection[0]]['checks_fail_tests_results'].setdefault(test,
                                                                                                     []).append(res)

        os.remove(tempfile_path)  # delete the NetCDF file

""" write to a json file (similar structure as to input file) """
outfile_path = os.path.join(OUTPUT_DIR, 'compliance_checker_results_cc-{version}.json'.format(
    version=compliance_checker.__version__))

with open(outfile_path, 'w') as outfile:
    json.dump(compliance_config, outfile, indent=4, sort_keys=True)

print("outputs results can be found at: {outfile_path}".format(outfile_path=outfile_path))
