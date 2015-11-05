#!/usr/bin/python

import unittest
import numpy as np
from datetime import datetime
import logging
import CurrentGenerator
import ACORNConstants
import ACORNUtils
import ACORNQC

import WERA
import CODAR

logging.getLogger().setLevel(logging.ERROR)

class TestStringMethods(unittest.TestCase):

    def testFileParsing(self):
        self.assertEqual(
            'NNB',
            ACORNUtils.getStation("IMOS_ACORN_RV_20150128T065500Z_NNB_FV00_radial.nc")
        )

        self.assertEqual(
            datetime(2015, 1, 28, 6, 55, 0, 0, None),
            ACORNUtils.getTimestamp("IMOS_ACORN_RV_20150128T065500Z_NNB_FV00_radial.nc")
        )

        self.assertEqual(
            "FV02",
            ACORNUtils.getFileVersion("IMOS_ACORN_RV_20150128T065500Z_NNB_FV02_radial.nc")
        )

        self.assertTrue(
            ACORNUtils.isQc("IMOS_ACORN_RV_20150128T065500Z_NNB_FV01_radial.nc")
        )

        self.assertFalse(
            ACORNUtils.isQc("IMOS_ACORN_RV_20150128T065500Z_NNB_FV00_radial.nc")
        )

    def testGetSiteDescription(self):
        self.assertEqual(
            ['LANC', 'GHED'],
            ACORNUtils.getSiteDescription("TURQ", datetime.utcnow())['stationsOrder']
        )

        self.assertEqual(
            [ 'SBRD', 'CRVT' ],
            ACORNUtils.getSiteDescription("TURQ", datetime.strptime("19730101T230000", "%Y%m%dT%H%M%S"))['stationsOrder']
        )

        self.assertEqual(
            "-before_20121215T000000",
            ACORNUtils.getSiteDescription("TURQ", datetime.strptime("19730101T230000", "%Y%m%dT%H%M%S"))['fileSuffix']
        )

        self.assertEqual(
            [ 'SBRD', 'GHED' ],
            ACORNUtils.getSiteDescription("TURQ", datetime.strptime("20130302T230000", "%Y%m%dT%H%M%S"))['stationsOrder']
        )

        self.assertEqual(
            "-before_20110301T040500",
            ACORNUtils.getSiteDescription("CBG", datetime.strptime("20110225T230000", "%Y%m%dT%H%M%S"))['fileSuffix']
        )

        self.assertFalse(
            'fileSuffix' in ACORNUtils.getSiteDescription("CBG", datetime.utcnow())
        )

    def testGetSiteFromStation(self):
        self.assertEqual("CBG", ACORNUtils.getSiteForStation("TAN"))
        self.assertEqual("CBG", ACORNUtils.getSiteForStation("LEI"))

        self.assertEqual("SAG", ACORNUtils.getSiteForStation("CWI"))
        self.assertEqual("SAG", ACORNUtils.getSiteForStation("CSP"))

        self.assertEqual("ROT", ACORNUtils.getSiteForStation("GUI"))
        self.assertEqual("ROT", ACORNUtils.getSiteForStation("FRE"))

        self.assertEqual("COF", ACORNUtils.getSiteForStation("RRK"))
        self.assertEqual("COF", ACORNUtils.getSiteForStation("NNB"))

    def testGenFilename(self):
        self.assertEqual(
            "IMOS_ACORN_RV_20150714T033000Z_GUI_FV00_radial.nc",
            ACORNUtils.genFilename(
                "GUI", datetime(2015, 7, 14, 3, 30, 0, 0, None),
                "RV", "00", "radial"
            )
        )

        self.assertEqual(
            "IMOS_ACORN_V_20150714T033000Z_ROT_FV01_1-hour-avg.nc",
            ACORNUtils.generateCurrentFilename(
                "ROT",
                datetime(2015, 7, 14, 3, 30, 0, 0, None),
                True
            )
        )

    def testGetCurrentTimestamp(self):
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
                ACORNUtils.getCurrentTimestamp(date)
            )

    def testGetRadialsForSite(self):
        expectedRadials = {
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
            expectedRadials,
            WERA.Util.getRadialsForSite("ROT", datetime(2015, 1, 28, 6, 30, 0, 0, None))
        )

    def testExpandArray(self):
        posArray = [ 0, 4, 9, 11, 12, 15 ]
        varArray = [ 0, 2, 3,  4,  6,  8 ]

        expectedArray = np.empty(16, dtype=np.int)
        expectedArray[:] = np.NAN

        expectedArray[0] = 0
        expectedArray[4] = 2
        expectedArray[9] = 3
        expectedArray[11] = 4
        expectedArray[12] = 6
        expectedArray[15] = 8

        np.testing.assert_array_equal(
            expectedArray,
            ACORNUtils.expandArray(posArray, varArray, 16)
        )

    def testWERAQCSpeedLimit(self):
        speedMatrix = np.array([
            np.array([1, 2, -4]),
            np.array([4, 2,  1]),
            np.array([3, 3,  3])
        ], dtype=np.float32)

        errorMatrix = np.array([
            np.array([np.nan, 2,      4]),
            np.array([4,      np.nan, 1]),
            np.array([2.9,    2.9,    np.nan])
        ], dtype=np.float32)

        expectedErrorMatrix = np.array([
            np.array([np.nan, 2,      np.nan]),
            np.array([np.nan, np.nan, 1]),
            np.array([2.9,    2.9,    np.nan])
        ], dtype=np.float32)

        stationData = {
            "CWI": {
                "speed": speedMatrix,
                "error": errorMatrix
            }
        }

        ACORNQC.enforceSpeedLimit(stationData, "speed", 3.1)

        # Expect errorMatrix to have nans where speed limit is exceeded
        np.testing.assert_array_equal(
            expectedErrorMatrix,
            stationData["CWI"]["error"]
        )

    def testWERAQCBragg(self):
        braggMatrix = np.array([
            np.array([11, 8.5, np.nan]),
            np.array([40, 20,  1]),
            np.array([3,  30,  9])
        ], dtype=np.float32)

        speedMatrix = np.array([
            np.array([np.nan, 2,      4]),
            np.array([4,      np.nan, 1]),
            np.array([3,      3,      np.nan])
        ], dtype=np.float32)

        expectedSpeedMatrix = np.array([
            np.array([np.nan, 2,      4]),
            np.array([4,      np.nan, np.nan]),
            np.array([np.nan, 3,      np.nan])
        ], dtype=np.float32)

        qcMatrix = np.array([
            np.array([np.nan, 1,      np.nan]),
            np.array([np.nan, np.nan, np.nan]),
            np.array([np.nan, np.nan, 0])
        ], dtype=np.float32)

        expectedQcMatrix = np.array([
            np.array([np.nan, 2,      np.nan]),
            np.array([np.nan, np.nan, np.nan]),
            np.array([np.nan, np.nan, 0])
        ], dtype=np.float32)

        stationData = {
            "CWI": {
                "bragg": braggMatrix,
                "speed": speedMatrix,
                "qc": qcMatrix
            }
        }

        ACORNQC.enforceSignalToNoiseRatio(stationData, "bragg", "qc", True, 8.0, 10.0)

        # Expect speedMatrix to have nans where bragg is too low
        np.testing.assert_array_equal(
            expectedSpeedMatrix,
            stationData["CWI"]["speed"]
        )

        # Expect qcMatrix to have 2 where bragg is "suspicious"
        np.testing.assert_array_equal(
            expectedQcMatrix,
            stationData["CWI"]["qc"]
        )

    def testWERAMeanError(self):
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

        expectedMeanError = np.array([
            np.array([
                error1, error2, error3, error4
            ])
        ],
        dtype=np.float64)

        np.testing.assert_array_equal(
            expectedMeanError,
            WERA.Util.meanError(error)
        )

    def testWERAQCLowQuality(self):
        braggMatrix = np.array([
            np.array([11, 8.5, np.nan]),
            np.array([40, 20,  1]),
            np.array([3,  30,  9])
        ], dtype=np.float32)

        expectedBraggMatrix = np.array([
            np.array([np.nan,  8.5, np.nan]),
            np.array([np.nan,  20,  1]),
            np.array([np.nan,  30,  np.nan])
        ], dtype=np.float32)

        speedMatrix = np.array([
            np.array([np.nan, 2, 4]),
            np.array([4,      2, 1]),
            np.array([3,      3, np.nan])
        ], dtype=np.float32)

        expectedSpeedMatrix = np.array([
            np.array([np.nan, 2, 4]),
            np.array([np.nan, 2, 1]),
            np.array([np.nan, 3, np.nan])
        ], dtype=np.float32)

        qcMatrix = np.array([
            np.array([np.nan, 2,      np.nan]),
            np.array([3,      np.nan, 2]),
            np.array([3,      1,      0])
        ], dtype=np.float32)

        stationData = {
            "CWI": {
                "bragg": braggMatrix,
                "speed": speedMatrix,
                "qc": qcMatrix
            }
        }

        ACORNQC.discardQcRange(stationData, "qc", True, 1, 2)

        # Expect speedMatrix to have nans where bragg is too low
        np.testing.assert_array_equal(
            expectedSpeedMatrix,
            stationData["CWI"]["speed"]
        )

    def testQCGdopMasking(self):
        gdop = np.array([165, 5, 155, 25, 35, 90, 25, 50, 0])

        qcMatrix = np.array([
            np.array([np.nan, 4, 5, 3,  1, 1,      2,      0, 1]),
            np.array([1,      4, 3, 2,  3, 1,      3,      0, 1]),
            np.array([3,      2, 4, 3, -3, np.nan, np.nan, 0, 2])
        ], dtype=np.float32)

        expectedQcMatrix = np.array([
            np.array([0, 4, 5, 3, 1, 1, 3, 0, 4]),
            np.array([4, 4, 3, 3, 3, 1, 3, 0, 4]),
            np.array([4, 4, 4, 3, 0, 0, 0, 0, 4])
        ], dtype=np.float32)

        expectedQcMatrixQcMode = np.array([
            np.array([1, 4, 5, 3, 1, 1, 3, 1, 4]),
            np.array([4, 4, 3, 3, 3, 1, 3, 1, 4]),
            np.array([4, 4, 4, 3, 1, 1, 1, 1, 4])
        ], dtype=np.float32)

        stationData = {
            "CWI": {
                "qc": qcMatrix
            }
        }

        # Expect QC matrix to update accordingly (non qc mode)
        stationData["CWI"]["qc"] = qcMatrix
        ACORNQC.gdopMasking(stationData, gdop, "qc", False, 20, 30)
        np.testing.assert_array_equal(
            expectedQcMatrix,
            stationData["CWI"]["qc"]
        )

        # Expect QC matrix to update accordingly (qc mode)
        stationData["CWI"]["qc"] = qcMatrix
        ACORNQC.gdopMasking(stationData, gdop, "qc", True, 20, 30)
        np.testing.assert_array_equal(
            expectedQcMatrixQcMode,
            stationData["CWI"]["qc"]
        )

    def testCODARGridAdjustment(self):
        lonDim = 3
        latDim = 4
        points = np.arange(lonDim * latDim)
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

        expectedArray = np.array([9, 10, 11, 6, 7, 8, 3, 4, 5, 0, 1, 2])

        np.testing.assert_array_equal(
            expectedArray,
            CODAR.Util.adjustGrid(points, lonDim, latDim)
        )

if __name__ == '__main__':
    unittest.main()
