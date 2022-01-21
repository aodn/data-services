#!/usr/bin/env python3
"""
unittest for lib/common/utils.py

author : besnard, laurent
"""

import datetime
import os
import unittest

from ardc_nrt.lib.common.lookup import lookup_get_sources_id_metadata, lookup_get_source_id_metadata,\
    lookup_get_nc_template, lookup_get_source_id_deployment_start_date, lookup_get_source_id_institution_code,\
    lookup_get_aodn_variable

TEST_ROOT = os.path.dirname(__file__)
NETCDF_FILE_PATH = os.path.join(TEST_ROOT, 'OMC_W_B10_20220301T000000Z_monthly_FV00.nc')


class TestLookup(unittest.TestCase):

    def test_lookup_get_sources_id_metadata(self):
        val_function = lookup_get_sources_id_metadata(TEST_ROOT)
        self.assertEqual("Mt Eliza", val_function['SPOT-0278']["site_name"])

    def test_lookup_get_source_id_metadata(self):
        val_function = lookup_get_source_id_metadata(TEST_ROOT, 'SPOT-0278')
        self.assertEqual("Mt Eliza", val_function["site_name"])

    def test_lookup_get_nc_template(self):
        # test failure of SPOT-0278 which requires a template_vic.json file missing in the test folder
        with self.assertRaises(ValueError):
            lookup_get_nc_template(TEST_ROOT, "SPOT-0278")

        val_function = lookup_get_nc_template(TEST_ROOT, 'SPOT-0170')
        self.assertEqual(os.path.join(TEST_ROOT, "template_uwa.json"),
                         val_function)

    def test_lookup_get_aodn_variable(self):
        #global VARIABLES_LOOKUP_FILENAME
        #VARIABLES_LOOKUP_FILENAME = os.path.join(TEST_ROOT, "variables_lookup")

        val_function = lookup_get_aodn_variable(TEST_ROOT, "meanPeriod")
        self.assertEqual("WPFM",
                         val_function)

    def test_lookup_get_source_id_institution_code(self):
        val_function = lookup_get_source_id_institution_code(TEST_ROOT, 'SPOT-0278')
        self.assertEqual("VIC", val_function)

    def test_lookup_get_source_id_deployment_start_date(self):
        val_function = lookup_get_source_id_deployment_start_date(TEST_ROOT, 'SPOT-0278')
        self.assertEqual(datetime.datetime(2020, 1, 1, 0, 0),
                         val_function)
