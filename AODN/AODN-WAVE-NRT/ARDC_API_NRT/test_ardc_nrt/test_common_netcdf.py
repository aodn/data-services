#!/usr/bin/env python3
"""
unittest for lib/common/utils.py

author : besnard, laurent
"""

import json
import os
import unittest

from ardc_nrt.lib.common.netcdf import nc_get_max_timestamp, merge_source_institution_json_template
from pandas import Timestamp

TEST_ROOT = os.path.dirname(__file__)
NETCDF_FILE_PATH = os.path.join(TEST_ROOT, 'OMC_W_B10_20220301T000000Z_monthly_FV00.nc')


class TestNetCDF(unittest.TestCase):
    def setUp(self):
        self.netcdf_file_path = NETCDF_FILE_PATH
        self.json_output_path = None

    def tearDown(self):
        if self.json_output_path:
            os.remove(self.json_output_path)

    def test_nc_get_max_timestamp(self):
        val_function = nc_get_max_timestamp(self.netcdf_file_path)
        self.assertEqual(Timestamp('2022-03-01 07:38:00+0000', tz='UTC'), val_function)

    def test_merge_source_institution_json_template(self):

        # test failure of SPOT-0278 which requires a template_vic.json file missing in the test folder
        with self.assertRaises(ValueError):
            merge_source_institution_json_template(TEST_ROOT, "SPOT-0278")

        # test
        self.json_output_path = merge_source_institution_json_template(TEST_ROOT, "SPOT-0170")
        with open(self.json_output_path) as json_obj:
            merged_json = json.load(json_obj)

        self.assertEqual("unittest: check value is overwritten",
                         merged_json["_variables"]["TIME"]["standard_name"])
