#!/usr/bin/env python3
import argparse
import os
import shutil
import tempfile
import unittest
from datetime import datetime

import numpy as np
import xbt_dm_imos_conversion
from netCDF4 import Dataset

TEST_ROOT = os.path.join(os.path.dirname(__file__), 'test/CSIRO2018')

CAMPAIGN_ROOT_CAMPAIGN_PATH = os.path.join(TEST_ROOT, 'CSIROXBT2018')
CAMPAIGN_ROOT_KEY_PATH = os.path.join(TEST_ROOT, 'CSIROXBT2018_keys.nc')
NETCDF_KEYS_CSIRO_PATH = 'CSIROXBT2018_keys.nc'

NETCDF_TEST_1_PATH = 'CSIROXBT2018/89/00/97/78ed.nc'
NETCDF_TEST_2_PATH = 'CSIROXBT2018/other/86ed.nc'


class TestSoopXbtDm(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """
        setup global variables since the program is not launched from __main__ as a script but directly within python
        interpreter
        """
        cls.tmp_dir = tempfile.mkdtemp()
        parser = argparse.ArgumentParser()
        cls.vargs = parser.parse_args()
        cls.vargs.log_file = os.path.join(cls.tmp_dir, 'xbt.log')
        xbt_dm_imos_conversion.global_vars(cls.vargs)
        xbt_dm_imos_conversion.INPUT_DIRNAME = CAMPAIGN_ROOT_CAMPAIGN_PATH

        cls.input_netcdf_1_path = os.path.join(TEST_ROOT, NETCDF_TEST_1_PATH)
        cls.input_netcdf_2_path = os.path.join(TEST_ROOT, NETCDF_TEST_2_PATH)
        cls.input_keys_csiro_path = os.path.join(TEST_ROOT, NETCDF_KEYS_CSIRO_PATH)

    def test_parse_gatts_nc(self):
        """
        test the parsing of global attributes from an edited or raw NetCDF
        """
        gatts = xbt_dm_imos_conversion.parse_gatts_nc(self.input_netcdf_1_path)
        self.assertEqual('OWKF2', gatts['Platform_code'])
        self.assertEqual('20130621', gatts['XBT_manufacturer_date_yyyymmdd'])
        self.assertEqual('CSIROXBT2018/89/00/97/78ed.nc', gatts['XBT_input_filename'])
        self.assertEqual('PX34', gatts['XBT_line'])
        self.assertEqual('JM3403', gatts['XBT_cruise_ID'])
        self.assertEqual('Sydney-Wellington', gatts['XBT_line_description'])
        self.assertEqual(89009778, gatts['XBT_uniqueid'])
        self.assertEqual(1100.25, gatts['geospatial_vertical_max'])
        self.assertEqual('AMMC', gatts['gts_insertion_node'])
        self.assertEqual('QC: QCed profile length is very short', gatts['postdrop_comments'])
        self.assertEqual('TURO/CSIRO Quoll XBT acquisition system', gatts['XBT_recorder_type'])

    def test_parse_annex_nc(self):
        """
        test the parsing of annex values from an edited or raw NetCDF
        """
        annex = xbt_dm_imos_conversion.parse_annex_nc(self.input_netcdf_1_path)
        self.assertEqual('TEMP', annex['prof_type'])
        self.assertEqual(['TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP'], annex['act_parm'])
        self.assertEqual(['QC', 'CS', 'CS', 'CS', 'CS', 'CS', 'HB', 'NG'], annex['act_code'])
        self.assertEqual(['CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB'], annex['prc_code'])
        self.assertEqual(['CS', 'CS', 'CS', 'CS', 'CS', 'CS', 'CS', 'CS'], annex['ident_code'])
        self.assertEqual([25.099, 25.099, 25.112, 25.12, 25.125, 25.128, 12.253, 12.253], annex['previous_val'])
        self.assertEqual(['1.0', '1.0', '1.0', '1.0', '1.0', '1.0', '1.0', '1.0'], annex['version_soft'])
        self.assertEqual([datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0),
                          datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0),
                          datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0),
                          datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0)], annex['prc_date'])

        np.testing.assert_array_almost_equal([0.67, 0.67, 1.34, 2.01, 2.68, 3.34, 274.45, 274.45], annex['aux_id'],
                                             decimal=3)

    def test_get_fallrate_eq_coef(self):
        """
        test the parsing of the fallrate coefficient type by matching the NetCDF input attribute with xbt_config
        """
        coef_a, coef_b = xbt_dm_imos_conversion.get_fallrate_eq_coef(self.input_netcdf_1_path)
        self.assertEqual(6.691, coef_a)
        self.assertEqual(-2.25, coef_b)

    def test_get_history_val(self):
        history_val = xbt_dm_imos_conversion.get_history_val()
        self.assertEqual('ADD YOUR VALUE', history_val)

    def test_get_recorder_type(self):
        """
        test the parsing of the recorder type by matching the NetCDF input attribute with xbt_config
        """
        recorder_type = xbt_dm_imos_conversion.get_recorder_type(self.input_netcdf_1_path)
        self.assertEqual('TURO/CSIRO Quoll XBT acquisition system', recorder_type)

    def test_parse_data_nc(self):
        """
        test the parsing of data values from an edited or raw NetCDF
        """
        data = xbt_dm_imos_conversion.parse_data_nc(self.input_netcdf_1_path)
        # test data
        np.testing.assert_array_almost_equal(13.75, np.nanmean(data['TEMP']).item(0), decimal=3)
        self.assertEqual(1, data['LATITUDE_quality_control'])
        self.assertEqual(0, np.sum(data['DEPTH_quality_control']).item())
        self.assertEqual((1747,), data['DEPTH_quality_control'].shape)

    def test_retrieve_keys_campaign_path(self):
        """
        test when a user use a different input argument to start the script, either a keys netcdf or folder input
        """
        self.vargs.input_xbt_campaign_path = CAMPAIGN_ROOT_KEY_PATH
        keys_file_path, input_xbt_campaign_path = xbt_dm_imos_conversion.retrieve_keys_campaign_path(self.vargs)
        self.assertEqual(CAMPAIGN_ROOT_KEY_PATH, keys_file_path)
        self.assertEqual(CAMPAIGN_ROOT_CAMPAIGN_PATH, input_xbt_campaign_path)

        self.vargs.input_xbt_campaign_path = CAMPAIGN_ROOT_CAMPAIGN_PATH
        keys_file_path, input_xbt_campaign_path = xbt_dm_imos_conversion.retrieve_keys_campaign_path(self.vargs)
        self.assertEqual(CAMPAIGN_ROOT_KEY_PATH, keys_file_path)
        self.assertEqual(CAMPAIGN_ROOT_CAMPAIGN_PATH, input_xbt_campaign_path)

    def test_parse_edited_nc_netcdf_test_1(self):
        """
        testing the output of parse_nc function
        """
        gatts, data, annex = xbt_dm_imos_conversion.parse_nc(self.input_netcdf_1_path)

        # test annex
        self.assertEqual(['TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP', 'TEMP'], annex['act_parm'])
        self.assertEqual(['QC', 'CS', 'CS', 'CS', 'CS', 'CS', 'HB', 'NG'], annex['act_code'])
        self.assertEqual(['CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB', 'CSCB'], annex['prc_code'])
        self.assertEqual(['CS', 'CS', 'CS', 'CS', 'CS', 'CS', 'CS', 'CS'], annex['ident_code'])

        self.assertEqual([25.099, 25.099, 25.112, 25.12, 25.125, 25.128, 12.253, 12.253], annex['previous_val'])
        self.assertEqual(['1.0', '1.0', '1.0', '1.0', '1.0', '1.0', '1.0', '1.0'], annex['version_soft'])
        self.assertEqual([datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0),
                          datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0),
                          datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0),
                          datetime(2018, 3, 22, 0, 0), datetime(2018, 3, 22, 0, 0)], annex['prc_date'])

        np.testing.assert_array_almost_equal([0.67, 0.67, 1.34, 2.01, 2.68, 3.34, 274.45, 274.45], annex['aux_id'],
                                             decimal=3)

        # test gatts
        self.assertEqual('OWKF2', gatts['Platform_code'])
        self.assertEqual('20130621', gatts['XBT_manufacturer_date_yyyymmdd'])
        self.assertEqual('CSIROXBT2018/89/00/97/78ed.nc', gatts['XBT_input_filename'])
        self.assertEqual('PX34', gatts['XBT_line'])
        self.assertEqual('JM3403', gatts['XBT_cruise_ID'])
        self.assertEqual('Sydney-Wellington', gatts['XBT_line_description'])
        self.assertEqual(89009778, gatts['XBT_uniqueid'])
        self.assertEqual(1100.25, gatts['geospatial_vertical_max'])

        # test data
        np.testing.assert_array_almost_equal(13.75, np.nanmean(data['TEMP']).item(0), decimal=3)
        self.assertEqual(1, data['LATITUDE_quality_control'])
        self.assertEqual(0, np.sum(data['DEPTH_quality_control']).item())
        self.assertEqual((1747,), data['DEPTH_quality_control'].shape)

    def test_netcdf_validation_netcdf_test_1(self):
        """
        testing the output NetCDF from process_xbt_file
        """
        nc_path = xbt_dm_imos_conversion.process_xbt_file(self.input_netcdf_1_path, self.tmp_dir)
        # test filename
        self.assertEqual('IMOS_SOOP-XBT_T_20180314T091400Z_PX34_FV01_ID-89009778.nc', os.path.basename(nc_path))

        with Dataset(nc_path, "r", format="NETCDF4") as output_netcdf_obj:
            # test global attributes
            self.assertEqual('JM3403', getattr(output_netcdf_obj, 'XBT_cruise_ID'))
            self.assertEqual('CSIROXBT2018/89/00/97/78ed.nc', getattr(output_netcdf_obj, 'XBT_input_filename'))
            self.assertEqual('PX34', getattr(output_netcdf_obj, 'XBT_line'))
            self.assertEqual('Sydney-Wellington', getattr(output_netcdf_obj, 'XBT_line_description'))
            self.assertEqual('OWKF2', getattr(output_netcdf_obj, 'Platform_code'))
            self.assertEqual(1207856, getattr(output_netcdf_obj, 'XBT_instrument_serialnumber'))
            np.testing.assert_array_almost_equal(0.67, getattr(output_netcdf_obj, 'geospatial_vertical_min'),
                                                 decimal=3)
            np.testing.assert_array_almost_equal(1100.25, getattr(output_netcdf_obj, 'geospatial_vertical_max'),
                                                 decimal=3)
            np.testing.assert_array_almost_equal(0.99931, getattr(output_netcdf_obj, 'XBT_calibration_SCALE'),
                                                 decimal=5)
            np.testing.assert_array_almost_equal(-8.1, getattr(output_netcdf_obj, 'XBT_calibration_OFFSET'),
                                                 decimal=1)
            np.testing.assert_array_almost_equal(30,
                                                 getattr(output_netcdf_obj, 'XBT_height_launch_above_water_in_meters'),
                                                 decimal=1)
            self.assertEqual('WMO Code table 477 code 72 "TURO/CSIRO Quoll XBT acquisition system"',
                             getattr(output_netcdf_obj, 'XBT_recorder_type'))
            self.assertEqual('WMO Code Table 1770 code 052 "a=6.691,b=-2.25"',
                             getattr(output_netcdf_obj, 'XBT_probetype_fallrate_equation'))

            # test data adjusted values
            np.testing.assert_array_almost_equal(np.float(25.131),
                                                 np.nanmax(output_netcdf_obj.variables['TEMP_ADJUSTED'][:]).item(0))
            np.testing.assert_array_almost_equal(0.67,
                                                 np.nanmin(output_netcdf_obj.variables['DEPTH_ADJUSTED'][:]).item(0),
                                                 decimal=3)
            np.testing.assert_array_almost_equal(-34.124, output_netcdf_obj.variables['LATITUDE'][:].item(0),
                                                 decimal=3)
            np.testing.assert_array_almost_equal(151.498, output_netcdf_obj.variables['LONGITUDE'][:].item(0),
                                                 decimal=3)
            self.assertEqual(5763, np.sum(output_netcdf_obj.variables['TEMP_ADJUSTED_quality_control'][:]).item())
            self.assertEqual(0, np.sum(output_netcdf_obj.variables['DEPTH_ADJUSTED_quality_control']).item())
            self.assertEqual((1747,), output_netcdf_obj.variables['DEPTH_ADJUSTED_quality_control'].shape)

            # test data raw values
            np.testing.assert_array_almost_equal(np.float(25.131),
                                                 np.nanmax(output_netcdf_obj.variables['TEMP'][:]).item(0))
            np.testing.assert_array_almost_equal(np.float(25.099),
                                                 output_netcdf_obj.variables['TEMP'][0])
            np.testing.assert_array_almost_equal(0.67, np.nanmin(output_netcdf_obj.variables['DEPTH'][:]).item(0),
                                                 decimal=3)
            # check the QC values are different between ed and raw
            np.testing.assert_array_almost_equal(0, np.nanmin(
                output_netcdf_obj.variables['DEPTH_quality_control'][:]).item(0))
            self.assertNotEqual(np.nanmean(output_netcdf_obj.variables['TEMP_quality_control'][:]),
                                np.nanmean(output_netcdf_obj.variables['TEMP_ADJUSTED_quality_control'][:]))

            self.assertEqual(6.691, getattr(output_netcdf_obj.variables['DEPTH'], 'fallrate_equation_coefficient_a'))
            self.assertEqual(-2.25, getattr(output_netcdf_obj.variables['DEPTH'], 'fallrate_equation_coefficient_b'))

            # test history set variables
            np.testing.assert_array_almost_equal(np.float(25.128),
                                                 np.max(output_netcdf_obj.variables['HISTORY_PREVIOUS_VALUE'][:]).item(
                                                     0))
            np.testing.assert_array_almost_equal([0.67, 0.67, 1.34, 2.01, 2.68, 3.34, 274.45, 274.45],
                                                 np.array(output_netcdf_obj.variables['HISTORY_START_DEPTH'][:]),
                                                 decimal=3)
            np.testing.assert_array_almost_equal([0.67, 0.67, 1.34, 2.01, 2.68, 3.34, 274.45, 274.45],
                                                 np.array(output_netcdf_obj.variables['HISTORY_STOP_DEPTH'][:]),
                                                 decimal=3)
            np.testing.assert_array_almost_equal([24917., 24917., 24917., 24917., 24917., 24917., 24917., 24917.],
                                                 np.array(output_netcdf_obj.variables['HISTORY_DATE'][:]),
                                                 decimal=3)
            self.assertEqual('CSCB', output_netcdf_obj.variables['HISTORY_STEP'][0])
            self.assertEqual('ADD YOUR VALUE', output_netcdf_obj.variables['HISTORY_SOFTWARE'][0])

    def test_gatt_input_xbt_filename_key_case(self):
        """
        testing value of XBT_input_filename global attribute
        case when input_xbt_campaign_path input argument is a keys.nc path
        """
        # initialise case when input_xbt_campaign_path is a key file
        self.vargs.input_xbt_campaign_path = CAMPAIGN_ROOT_KEY_PATH
        keys_file_path, input_xbt_campaign_path = xbt_dm_imos_conversion.retrieve_keys_campaign_path(self.vargs)
        xbt_dm_imos_conversion.INPUT_DIRNAME = input_xbt_campaign_path

        nc_path = xbt_dm_imos_conversion.process_xbt_file(self.input_netcdf_1_path, self.tmp_dir)
        with Dataset(nc_path, "r", format="NETCDF4") as output_netcdf_obj:
            # test global attributes
            self.assertEqual('CSIROXBT2018/89/00/97/78ed.nc', getattr(output_netcdf_obj, 'XBT_input_filename'))

    def test_gatt_input_xbt_filename_campaign_case(self):
        """
        testing value of XBT_input_filename global attribute
        case when input_xbt_campaign_path input argument is a campaign folder path
        """
        # initialise case when input_xbt_campaign_path is a campaign folder
        self.vargs.input_xbt_campaign_path = CAMPAIGN_ROOT_CAMPAIGN_PATH
        keys_file_path, input_xbt_campaign_path = xbt_dm_imos_conversion.retrieve_keys_campaign_path(self.vargs)
        xbt_dm_imos_conversion.INPUT_DIRNAME = input_xbt_campaign_path

        nc_path = xbt_dm_imos_conversion.process_xbt_file(self.input_netcdf_1_path, self.tmp_dir)
        with Dataset(nc_path, "r", format="NETCDF4") as output_netcdf_obj:
            # test global attributes
            self.assertEqual('CSIROXBT2018/89/00/97/78ed.nc', getattr(output_netcdf_obj, 'XBT_input_filename'))

    def test_parse_edited_nc_netcdf_test_2(self):
        """
        testing the output of parse_nc function with masked values of prof
        """
        gatts, data, annex = xbt_dm_imos_conversion.parse_nc(self.input_netcdf_2_path)

        # test data
        self.assertEqual(3264, np.sum(data['DEPTH_quality_control']).item())
        self.assertEqual((1632,), data['DEPTH_quality_control'].shape)

    def test_parse_keys_nc(self):
        """
        testing the parsing of the keys netcdf file
        """
        data = xbt_dm_imos_conversion.parse_keys_nc(self.input_keys_csiro_path)
        self.assertEqual(170, len(data['station_number']))
        self.assertTrue(89009912 in data['station_number'])

    def test_is_xbt_prof_to_be_parsed(self):
        self.assertTrue(
            xbt_dm_imos_conversion.is_xbt_prof_to_be_parsed(self.input_netcdf_1_path, self.input_keys_csiro_path))
        self.assertFalse(
            xbt_dm_imos_conversion.is_xbt_prof_to_be_parsed(self.input_netcdf_2_path, self.input_keys_csiro_path))

    def test_raw_for_ed_path(self):
        self.assertTrue(xbt_dm_imos_conversion.raw_for_ed_path(self.input_netcdf_1_path).endswith('raw.nc'))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp_dir)


if __name__ == '__main__':
    unittest.main()
