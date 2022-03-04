#!/usr/bin/env python3
"""
unittest for lib/common/utils.py

author : besnard, laurent
"""

import json
import os
import unittest

import pandas
from ardc_nrt.lib.common.netcdf import nc_get_max_timestamp, wave
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
            ardc_wave = wave(TEST_ROOT, "SPOT-0278", pandas.DataFrame, self.json_output_path)
            ardc_wave.merge_source_id_with_institution_template()

        # test
        ardc_wave = wave(TEST_ROOT, "SPOT-0170", pandas.DataFrame, self.json_output_path)
        self.json_output_path = ardc_wave.merge_source_id_with_institution_template()
        with open(self.json_output_path) as json_obj:
            merged_json = json.load(json_obj)

        self.assertEqual("unittest: check value is overwritten",
                         merged_json["_variables"]["TIME"]["standard_name"])
