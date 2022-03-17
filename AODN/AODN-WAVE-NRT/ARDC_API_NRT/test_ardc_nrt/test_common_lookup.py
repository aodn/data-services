#!/usr/bin/env python3
"""
unittest for lib/common/utils.py

author : besnard, laurent
"""

import datetime
import os
import pandas
import unittest

from ardc_nrt.lib.common.lookup import lookup

TEST_ROOT = os.path.dirname(__file__)


class TestLookup(unittest.TestCase):
    def setUp(self):
        self.ardc_lookup = lookup(TEST_ROOT)

    def test_lookup_get_sources_id_metadata(self):
        val_function = self.ardc_lookup.get_sources_id_metadata()
        self.assertEqual("Mt Eliza", val_function['SPOT-0278']["site_name"])

    def test_lookup_get_source_id_metadata(self):
        #self.ardc_lookup.source_id='SPOT-0278')
        val_function = self.ardc_lookup.get_source_id_metadata('SPOT-0278')
        self.assertEqual("Mt Eliza", val_function["site_name"])

    def test_lookup_get_institution_netcdf_template(self):
        # test failure of SPOT-0278 which requires a template_vic.json file missing in the test folder
        with self.assertRaises(ValueError):
            self.ardc_lookup.get_institution_netcdf_template('SPOT-0278')

        val_function = self.ardc_lookup.get_institution_netcdf_template('SPOT-0170')
        self.assertEqual(os.path.join(TEST_ROOT, "template_uwa.json"),
                         val_function)

    def test_lookup_get_matching_aodn_variable(self):
        val_function = self.ardc_lookup.get_matching_aodn_variable("meanPeriod")
        self.assertEqual("WPFM",
                         val_function)

    def test_lookup_get_source_id_institution_code(self):
        val_function = self.ardc_lookup.get_source_id_institution_code( 'SPOT-0278')
        self.assertEqual("VIC", val_function)

    def test_lookup_get_source_id_deployment_start_date(self):
        val_function = self.ardc_lookup.get_source_id_deployment_start_date('SPOT-0278')
        self.assertEqual(pandas.Timestamp('2020-01-01 00:00:00+0000', tz='UTC'),
                         val_function)


if __name__ == '__main__':
    unittest.main()
