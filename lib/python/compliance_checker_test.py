#!/usr/bin/env python3
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

The results will be output by default to a temporary directory (see outfile_path variable):
* a json file with a similar structure to the CONFIG_FILE containing the different results
* if some tests fail, the compliance checker output files will be saved in the same output directory

If all test succeeded, the string 'False' should not exist in the output json file. If "False"
is to be found, this means a test didn't output the required result.

Example:
    ./compliance_checker_test.py -h

author: Besnard, Laurent
"""
import argparse
import json
import os
import tempfile
from urllib.request import urlretrieve

import cc_plugin_imos
import cf_units
import compliance_checker

from util import pass_netcdf_checker

TEST_ROOT = os.path.join(os.path.dirname(__file__))
CONFIG_FILE = os.path.join(TEST_ROOT, "compliance_checker_imos_files_config.json")


def download_temporary_netcdf(url):
    """
    downloads NetCDF into the output folder
    """
    netcdf_path = os.path.join(OUTPUT_DIR, 'NetCDF', os.path.basename(url))
    if not os.path.exists(os.path.dirname((netcdf_path))):
        os.makedirs(os.path.dirname((netcdf_path)))

    if not os.path.exists(netcdf_path):
        urlretrieve(url, netcdf_path)

    return netcdf_path


def netcdf_tests_info(sub_collection):
    """
    parse json sub collection dictionary to retrieve essential information needed to run appropriate checks on a
    sub collection

    return dictionary
    """
    # handling default parameter for criteria
    criteria = sub_collection[1]['check_params']['criteria']
    if criteria == []:
        criteria = "normal"
    else:
        criteria = criteria[0]

    return {
        'file_url': sub_collection[1]['path'][0],
        'check_success_tests': sub_collection[1]['check_params']['checks_success'],
        'check_fail_tests': sub_collection[1]['check_params']['checks_fail'],
        'criteria': criteria,
        'skip_checks': sub_collection[1]['check_params']['skip_checks']
    }


def run_test_type_netcdf(test_type, sub_collection, tempfile_nc_path):
    """
    run required test type on NetCDF. return results as a dictionary with a similar structure as the json input

    test_type: authorized values 'check_success_tests', 'check_fail_tests'
    sub_collection: dictionary from the json input specific to the NetCDF to test
    tempfile_nc_path: the path of the downloaded NetCDF file to test
    """
    info_collection = netcdf_tests_info(sub_collection)

    # para_results_att value is a result attribute of the json file
    if not(test_type == 'check_success_tests' or test_type == 'check_fail_tests'):
        raise ValueError("test_type: {test_type} not in ['check_success_tests' 'check_fail_tests']".
                         format(test_type=test_type))

    sub_collection_tests_results = {}
    nc_filename = os.path.basename(info_collection['file_url'])
    print('\t{nc_filename}'.format(nc_filename=nc_filename))

    print('\t\t{test_type}: {tests}'.format(test_type=test_type,
                                            tests=info_collection[test_type]))

    for test in info_collection[test_type]:
        try:
            res, keep_outfile_path = pass_netcdf_checker(
                tempfile_nc_path, tests=[test],
                criteria=info_collection['criteria'],
                skip_checks=info_collection['skip_checks'],
                keep_outfile=True,
                output_format='text'
            )

        except ValueError:
            print("compliance checker failed for \"{test}\" applied to {nc_filename}".format(
                test=test,
                nc_filename=nc_filename))

            res = False

        # If the test fails, the compliance output-file is saved and moved to OUTPUT_DIR
        if res is False:
            err_filename = '{filename}_{test}_error_results.txt'.format(filename=nc_filename,
                                                                        test=test)
            # adding a failure key/value in the dictionary output
            sub_collection_tests_results.setdefault('{test}_failure_filename'.format(test=test), []).append(
                err_filename)

            os.rename(keep_outfile_path, os.path.join(OUTPUT_DIR, err_filename))  # save file when a test has an error
        else:
            os.remove(keep_outfile_path)

        # adding test results to json
        sub_collection_tests_results.setdefault(test, []).append(res)

    return sub_collection_tests_results


def run_test_all_collection(compliance_config):
    # collection is equivalent to a facility/sub-facility in the input json-file
    for collection in compliance_config:
        print("Running test suite for: {collection}".format(collection=collection))

        for sub_collection in compliance_config[collection].items():
            try:
                info = netcdf_tests_info(sub_collection)
                tempfile_nc_path = download_temporary_netcdf(info['file_url'])

                # running checks
                for param_results_att in ['check_success_tests', 'check_fail_tests' ]:
                    sub_collection_tests_results = run_test_type_netcdf(param_results_att, sub_collection,
                                                                        tempfile_nc_path)
                    compliance_config[collection][sub_collection[0]][
                        '{param_results_att}_results'.format(param_results_att=param_results_att)
                    ] = sub_collection_tests_results

            except Exception as err:
                raise err

    return compliance_config


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser(description=
                                     'Run the compliance checker on various NetCDFs.\n '
                                     'see compliance_checker_imos_files_config.json')
    parser.add_argument('-o', '--output-path',
                        dest='output_path',
                        type=str,
                        default=None,
                        help="output directory of compliance checker results. (Optional)",
                        required=False)
    vargs = parser.parse_args()

    if vargs.output_path is None:
        vargs.output_path = tempfile.mkdtemp(prefix='compliance_checker_testing_results_')

    if not os.path.exists(vargs.output_path):
        try:
            os.makedirs(vargs.output_path)
        except Exception:
            raise ValueError('{path} can not be created'.format(path=vargs.output_path))
            sys.exit(1)

    global OUTPUT_DIR
    OUTPUT_DIR = vargs.output_path

    return vargs


if __name__ == '__main__':
    vargs = args()

    with open(CONFIG_FILE, 'r') as f:
        compliance_config = json.load(f)

    print("compliance checker {cc_version}\n" \
          "cf units {cf_version}\n" \
          "imos plugin {cc_plugin_imos}".format(cc_version=compliance_checker.__version__,
                                                cf_version=cf_units.__version__,
                                                cc_plugin_imos=cc_plugin_imos.__version__))

    compliance_results = run_test_all_collection(compliance_config)

    # write to a json file (similar structure as to input file)
    outfile_path = os.path.join(OUTPUT_DIR,
                                'compliance_checker_results_ioos-cc-{cc_version}_imos-plugin-{cc_plugin_imos}.json'.
                                format(cc_version=compliance_checker.__version__,
                                       cc_plugin_imos=cc_plugin_imos.__version__)
                                )

    with open(outfile_path, 'w') as outfile:
        json.dump(compliance_results, outfile, indent=4, sort_keys=True)

    print("compliance outputs results can be found at: {output_path}".format(output_path=OUTPUT_DIR))