#!/usr/bin/python

import unittest
import numpy as np
from datetime import datetime
import logging
import current_generator
import acorn_constants
import acorn_utils
import acorn_qc

import wera
import codar

logging.getLogger().setLevel(logging.ERROR)

class TestCurrentGenerator(unittest.TestCase):

    def test_file_parsing(self):
        self.assertEqual(
            'NNB',
            acorn_utils.get_station("IMOS_ACORN_RV_20150128T065500Z_NNB_FV00_radial.nc")
        )

        self.assertEqual(
            datetime(2015, 1, 28, 6, 55, 0, 0, None),
            acorn_utils.get_timestamp("IMOS_ACORN_RV_20150128T065500Z_NNB_FV00_radial.nc")
        )

        self.assertEqual(
            "FV02",
            acorn_utils.get_file_version("IMOS_ACORN_RV_20150128T065500Z_NNB_FV02_radial.nc")
        )

        self.assertTrue(
            acorn_utils.is_qc("IMOS_ACORN_RV_20150128T065500Z_NNB_FV01_radial.nc")
        )

        self.assertFalse(
            acorn_utils.is_qc("IMOS_ACORN_RV_20150128T065500Z_NNB_FV00_radial.nc")
        )

    def test_get_site_description(self):
        self.assertEqual(
            ['LANC', 'GHED'],
            acorn_utils.get_site_description("TURQ", datetime.utcnow())['stations_order']
        )

        self.assertEqual(
            [ 'SBRD', 'CRVT' ],
            acorn_utils.get_site_description("TURQ", datetime.strptime("19730101T230000", "%Y%m%dT%H%M%S"))['stations_order']
        )

        self.assertEqual(
            "-before_20121215T000000",
            acorn_utils.get_site_description("TURQ", datetime.strptime("19730101T230000", "%Y%m%dT%H%M%S"))['file_suffix']
        )

        self.assertEqual(
            [ 'SBRD', 'GHED' ],
            acorn_utils.get_site_description("TURQ", datetime.strptime("20130302T230000", "%Y%m%dT%H%M%S"))['stations_order']
        )

        self.assertEqual(
            "-before_20110301T040500",
            acorn_utils.get_site_description("CBG", datetime.strptime("20110225T230000", "%Y%m%dT%H%M%S"))['file_suffix']
        )

        self.assertFalse(
            'file_suffix' in acorn_utils.get_site_description("CBG", datetime.utcnow())
        )

    def test_get_site_from_station(self):
        self.assertEqual("CBG", acorn_utils.get_site_for_station("TAN"))
        self.assertEqual("CBG", acorn_utils.get_site_for_station("LEI"))

        self.assertEqual("SAG", acorn_utils.get_site_for_station("CWI"))
        self.assertEqual("SAG", acorn_utils.get_site_for_station("CSP"))

        self.assertEqual("ROT", acorn_utils.get_site_for_station("GUI"))
        self.assertEqual("ROT", acorn_utils.get_site_for_station("FRE"))

        self.assertEqual("COF", acorn_utils.get_site_for_station("RRK"))
        self.assertEqual("COF", acorn_utils.get_site_for_station("NNB"))

    def test_gen_filename(self):
        self.assertEqual(
            "IMOS_ACORN_RV_20150714T033000Z_GUI_FV00_radial.nc",
            acorn_utils.gen_filename(
                "GUI", datetime(2015, 7, 14, 3, 30, 0, 0, None),
                "RV", "00", "radial"
            )
        )

        self.assertEqual(
            "IMOS_ACORN_V_20150714T033000Z_ROT_FV01_1-hour-avg.nc",
            acorn_utils.generate_current_filename(
                "ROT",
                datetime(2015, 7, 14, 3, 30, 0, 0, None),
                True
            )
        )

    def test_get_current_timestamp(self):
        dates = [
            datetime(2015, 1, 28, 6, 00, 0, 1, None),
            datetime(2015, 1, 28, 6, 00, 0, 0, None),
            datetime(2015, 1, 28, 6, 10, 0, 0, None),
            datetime(2015, 1, 28, 6, 20, 0, 0, None),
            datetime(2015, 1, 28, 6, 30, 0, 0, None),
            datetime(2015, 1, 28, 6, 40, 0, 0, None),
            datetime(2015, 1, 28, 6, 50, 0, 0, None),
            datetime(2015, 1, 28, 6, 59, 59, 0, None)
        ]

        for date in dates:
            self.assertEqual(
                datetime(2015, 1, 28, 6, 30, 0, 0, None),
                acorn_utils.get_current_timestamp(date)
            )

    def test_get_radials_from_site(self):
        expected_radials = {
            "GUI": [
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T060000Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T060500Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T061000Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T061500Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T062000Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T062500Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T063000Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T063500Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T064000Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T064500Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T065000Z_GUI_FV00_radial.nc",
                "GUI/2015/01/28/IMOS_ACORN_RV_20150128T065500Z_GUI_FV00_radial.nc"
            ],

            "FRE": [
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T060000Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T060500Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T061000Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T061500Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T062000Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T062500Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T063000Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T063500Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T064000Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T064500Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T065000Z_FRE_FV00_radial.nc",
                "FRE/2015/01/28/IMOS_ACORN_RV_20150128T065500Z_FRE_FV00_radial.nc"
            ]
        }

        self.assertEqual(
            expected_radials,
            wera.Util.get_radials_for_site("ROT", datetime(2015, 1, 28, 6, 30, 0, 0, None))
        )

    def test_expand_array(self):
        pos_array = [ 0, 4, 9, 11, 12, 15 ]
        var_array = [ 0, 2, 3,  4,  6,  8 ]

        expected_array = np.empty(16, dtype=np.int)
        expected_array[:] = np.NAN

        expected_array[0] = 0
        expected_array[4] = 2
        expected_array[9] = 3
        expected_array[11] = 4
        expected_array[12] = 6
        expected_array[15] = 8

        np.testing.assert_array_equal(
            expected_array,
            acorn_utils.expand_array(pos_array, var_array, 16)
        )

    def testWERAQCSpeedLimit(self):
        speed_matrix = np.array([
            np.array([1, 2, -4]),
            np.array([4, 2,  1]),
            np.array([3, 3,  3])
        ], dtype=np.float32)

        error_matrix = np.array([
            np.array([np.nan, 2,      4]),
            np.array([4,      np.nan, 1]),
            np.array([2.9,    2.9,    np.nan])
        ], dtype=np.float32)

        expected_error_matrix = np.array([
            np.array([np.nan, 2,      np.nan]),
            np.array([np.nan, np.nan, 1]),
            np.array([2.9,    2.9,    np.nan])
        ], dtype=np.float32)

        station_data = {
            "CWI": {
                "speed": speed_matrix,
                "error": error_matrix
            }
        }

        acorn_qc.enforce_speed_limit(station_data, "speed", 3.1)

        # Expect error_matrix to have nans where speed limit is exceeded
        np.testing.assert_array_equal(
            expected_error_matrix,
            station_data["CWI"]["error"]
        )

    def test_wera_qc_bragg(self):
        bragg_matrix = np.array([
            np.array([11, 8.5, np.nan]),
            np.array([40, 20,  1]),
            np.array([3,  30,  9])
        ], dtype=np.float32)

        speed_matrix = np.array([
            np.array([np.nan, 2,      4]),
            np.array([4,      np.nan, 1]),
            np.array([3,      3,      np.nan])
        ], dtype=np.float32)

        expected_speed_matrix = np.array([
            np.array([np.nan, 2,      4]),
            np.array([4,      np.nan, np.nan]),
            np.array([np.nan, 3,      np.nan])
        ], dtype=np.float32)

        qc_matrix = np.array([
            np.array([np.nan, 1,      np.nan]),
            np.array([np.nan, np.nan, np.nan]),
            np.array([np.nan, np.nan, 0])
        ], dtype=np.float32)

        expected_qc_matrix = np.array([
            np.array([np.nan, 2,      np.nan]),
            np.array([np.nan, np.nan, np.nan]),
            np.array([np.nan, np.nan, 0])
        ], dtype=np.float32)

        station_data = {
            "CWI": {
                "bragg": bragg_matrix,
                "speed": speed_matrix,
                "qc": qc_matrix
            }
        }

        acorn_qc.enforce_signal_to_noise_ratio(station_data, "bragg", "qc", True, 8.0, 10.0)

        # Expect speed_matrix to have nans where bragg is too low
        np.testing.assert_array_equal(
            expected_speed_matrix,
            station_data["CWI"]["speed"]
        )

        # Expect qc_matrix to have 2 where bragg is "suspicious"
        np.testing.assert_array_equal(
            expected_qc_matrix,
            station_data["CWI"]["qc"]
        )

    def test_wera_mean_error(self):
        error = np.array([
            np.array([
                np.array([np.nan, 0.1,    0.9, np.nan]),
            ]),
            np.array([
                np.array([0.4,    np.nan, 0.7, np.nan]),
            ]),
            np.array([
                np.array([0.5,    np.nan, 0.6, np.nan])
            ]),
        ], dtype=np.float64)

        error1 = np.sqrt((0.4 ** 2 + 0.5 ** 2) / 2)
        error2 = np.sqrt((0.1 ** 2) / 1)
        error3 = np.sqrt((0.9 ** 2 + 0.7 ** 2 + 0.6 ** 2) / 3)
        error4 = np.nan

        expected_mean_error = np.array([
            np.array([
                error1, error2, error3, error4
            ])
        ],
        dtype=np.float64)

        np.testing.assert_array_equal(
            expected_mean_error,
            wera.Util.mean_error(error)
        )

    def test_wera_qc_low_quality(self):
        bragg_matrix = np.array([
            np.array([11, 8.5, np.nan]),
            np.array([40, 20,  1]),
            np.array([3,  30,  9])
        ], dtype=np.float32)

        speed_matrix = np.array([
            np.array([np.nan, 2, 4]),
            np.array([4,      2, 1]),
            np.array([3,      3, np.nan])
        ], dtype=np.float32)

        expected_speed_matrix = np.array([
            np.array([np.nan, 2, 4]),
            np.array([np.nan, 2, 1]),
            np.array([np.nan, 3, np.nan])
        ], dtype=np.float32)

        qc_matrix = np.array([
            np.array([np.nan, 2,      np.nan]),
            np.array([3,      np.nan, 2]),
            np.array([3,      1,      0])
        ], dtype=np.float32)

        station_data = {
            "CWI": {
                "bragg": bragg_matrix,
                "speed": speed_matrix,
                "qc": qc_matrix
            }
        }

        acorn_qc.discard_qc_range(station_data, "qc", True, 1, 2)

        # Expect speed_matrix to have nans where bragg is too low
        np.testing.assert_array_equal(
            expected_speed_matrix,
            station_data["CWI"]["speed"]
        )

    def test_qc_gdop_masking(self):
        gdop = np.array([165, 5, 155, 25, 35, 90, 25, 50, 0])

        qc_matrix = np.array([
            np.array([np.nan, 4, 5, 3,  1, 1,      2,      0, 1]),
            np.array([1,      4, 3, 2,  3, 1,      3,      0, 1]),
            np.array([3,      2, 4, 3, -3, np.nan, np.nan, 0, 2])
        ], dtype=np.float32)

        expected_qc_matrix = np.array([
            np.array([0, 4, 5, 3, 1, 1, 3, 0, 4]),
            np.array([4, 4, 3, 3, 3, 1, 3, 0, 4]),
            np.array([4, 4, 4, 3, 0, 0, 0, 0, 4])
        ], dtype=np.float32)

        expected_qc_matrix_qc_mode = np.array([
            np.array([1, 4, 5, 3, 1, 1, 3, 1, 4]),
            np.array([4, 4, 3, 3, 3, 1, 3, 1, 4]),
            np.array([4, 4, 4, 3, 1, 1, 1, 1, 4])
        ], dtype=np.float32)

        station_data = {
            "CWI": {
                "qc": qc_matrix
            }
        }

        # Expect QC matrix to update accordingly (non qc mode)
        station_data["CWI"]["qc"] = qc_matrix
        acorn_qc.gdop_masking(station_data, gdop, "qc", False, 20, 30)
        np.testing.assert_array_equal(
            expected_qc_matrix,
            station_data["CWI"]["qc"]
        )

        # Expect QC matrix to update accordingly (qc mode)
        station_data["CWI"]["qc"] = qc_matrix
        acorn_qc.gdop_masking(station_data, gdop, "qc", True, 20, 30)
        np.testing.assert_array_equal(
            expected_qc_matrix_qc_mode,
            station_data["CWI"]["qc"]
        )

    def test_codar_grid_adjustment(self):
        lon_dim = 3
        lat_dim = 4
        points = np.arange(lon_dim * lat_dim)
        # Function should order points from bottom-left to top-right to be
        # top-left to bottom-right

        # We start with:
        # 0  1  2  3
        # 4  5  6  7
        # 8  9 10 11

        # We are expecting:
        # 9 10 11
        # 6 7 8
        # 3 4 5
        # 0 1 2

        expected_array = np.array([9, 10, 11, 6, 7, 8, 3, 4, 5, 0, 1, 2])

        np.testing.assert_array_equal(
            expected_array,
            codar.Util.adjust_grid(points, lon_dim, lat_dim)
        )

if __name__ == '__main__':
    unittest.main()
