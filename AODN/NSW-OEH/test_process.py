import os
import unittest
import zipfile

import process_zip as pz

TEST_ROOT = os.path.join(os.path.dirname(__file__))
GOOD_SHP_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20151029_PortHackingBateBay_MB_SHP.zip')
BAD_SURVEY_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20170601_BadSurvey_MB.zip')
CORRUPTED_SHP_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20111111_Corrupted_SHP.zip')


def get_shp_path(zipfile_path):
    """Return the path of a shapefile (.shp) within a zip file"""

    with zipfile.ZipFile(zipfile_path) as zf:
        path_list = zf.namelist()
    paths = [path for path in path_list if path.endswith('.shp')]

    assert len(paths) == 1, "Expected exactly 1 shapefile in zip, found {n}".format(n=len(paths))

    return '/' + paths[0]


class TestProcessZip(unittest.TestCase):
    def test_is_date(self):
        self.assertTrue(pz.is_date('20170601'))
        self.assertFalse(pz.is_date('170601'))
        self.assertFalse(pz.is_date('June2017'))
        self.assertFalse(pz.is_date('2017-06-01'))
        self.assertFalse(pz.is_date('17/06/01'))

    def test_check_crs(self):
        for crs in ('W84Z55', 'W84Z56'):
            self.assertListEqual(pz.check_crs(crs), [])
        for crs in ('', 'NONE', 'W84Z42'):
            self.assertEqual(len(pz.check_crs(crs)), 1)

    def test_get_name_fields(self):
        in_fld = ['one', 'two', 'three']
        fld, ext = pz.get_name_fields('_'.join(in_fld))
        self.assertListEqual(in_fld, fld)
        self.assertEqual('', ext)

        in_fld = ['NSWOEH', '20151029', 'PortHackingBateBay', 'MB']
        in_ext = 'zip'
        fld, ext = pz.get_name_fields('_'.join(in_fld) + '.' + in_ext)
        self.assertListEqual(in_fld, fld)
        self.assertEqual(in_ext, ext)

    def test_get_survey_name(self):
        self.assertEqual('20151029_PortHackingBateBay',
                         pz.get_survey_name('NSWOEH_20151029_PortHackingBateBay_MB.shp'))
        self.assertEqual('20120921_TweedRiver',
                         pz.get_survey_name('NSWOEH_20120921_TweedRiver_STAX_SHP.cpg'))
        self.assertEqual('', pz.get_survey_name('NOT_NSWOEH_file.zip'))

    def test_check_name_good_mb(self):
        good_names = ['NSWOEH_20151029_PortHackingBateBay_MB.zip',
                      'NSWOEH_20151029_PortHackingBateBay_MB_ScientificRigour.pdf',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.CPG',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.dbf',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.prj',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.sbn',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.sbx',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.shp',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.shp.xml',
                      'NSWOEH_20151029_PortHackingBateBay_MB_SHP.shx',
                      'NSWOEH_20151029_PortHackingBateBay_MB_BKSGRD001GSS_W84Z56GRY_FLD744_20151221_FV02.sd',
                      'NSWOEH_20151029_PortHackingBateBay_MB_BKSGRD001GSS_W84Z56GRY_FLD744_20151221_FV02.tiff',
                      'NSWOEH_20151029_PortHackingBateBay_MB_BTYGRD002GSS_W84Z56AHD_FLD744_20151223_FV02.tif',
                      'NSWOEH_20151029_PortHackingBateBay_MB_BKSGRD002GSS_W84Z56GRY_FLD744_20151221_FV02.xya',
                      'NSWOEH_20151029_PortHackingBateBay_MB_BTYGRD002GSS_W84Z56AHD_FLD744_20151221_FV02.xyz'
                      ]
        for name in good_names:
            msg = pz.check_name(name)
            self.assertEqual([], msg, "Unexpected messages for {name}:\n{msg}".format(name=name, msg=msg))

    def test_check_name_short(self):
            self.assertEqual(["File name should have at least 4 underscore-separated fields."],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay.zip')
                         )

    def test_check_name_bad_method(self):
        self.assertEqual(["Field 4 should be a valid survey method code (MB, STAX)"],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay_BBB.zip')
                         )

    def test_check_name_bad_rigour(self):
        self.assertEqual(["Unknown extension 'doc'",
                          "The Scientific Rigour (metadata) sheet must be in PDF format."],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay_MB_ScientificRigour.doc')
                         )

    def test_check_name_bad_first3(self):
        msg = pz.check_name('IMOS_170202_N0-name_MB.what')
        self.assertItemsEqual(["File name must start with 'NSWOEH'",
                               "Field 2 should be a valid date (YYYYMMDD).",
                               "Field 3 should be a location code consisting only of letters."],
                              msg
                              )

    # TODO: unittests for fields beyond the first 4

    def test_check_name_good_stax(self):
        good_names = ['NSWOEH_20120921_TweedRiver_STAX_SHP.shx',
                      'NSWOEH_20120921_TweedRiver_STAX_RV12_AHD_MGA56_SEPT2012_TINMODEL_COVERAGE.dbf',
                      'NSWOEH_20120921_TweedRiver_STAX_2012_09_OEH_TWEED_RIVER_SURVEY.zip',
                      'NSWOEH_20111125_KingscliffBeach_STAX_56873s01.pdf',
                      'NSWOEH_20111125_KingscliffBeach_STAX_KingscliffBeach2011_AHD_MGA.xyz',
                      'NSWOEH_20111125_KingscliffBeach_STAX_KingscliffBeach2011.TXT',
                      'NSWOEH_20111125_KingscliffBeach_STAX_KingscliffBeach2011_AHD_MGA.sbn',
                      'NSWOEH_20111125_KingscliffBeach_STAX_log',
                      'NSWOEH_20111125_KingscliffBeach_STAX_schema.ini',
                      'NSWOEH_20141120_BengelloBeachBatemans_STAX_2014_1120_TLS_North_Bengello_Broulee_Beach_0.5m.xyz'
                      ]
        for name in good_names:
            msg = pz.check_name(name)
            self.assertEqual([], msg, "Unexpected messages for {name}:\n{msg}".format(name=name, msg=msg))

        # msg = pz.check_name('NSWOEH_20151029_PortHackingBateBay.what')
        # self.assertItemsEqual(, msg)

    def test_good_shapefile(self):
        shp_path = get_shp_path(GOOD_SHP_ZIP)
        self.assertEqual([], pz.check_shapefile(shp_path, GOOD_SHP_ZIP))

    def test_bad_shapefile(self):
        shp_path = get_shp_path(BAD_SURVEY_ZIP)
        self.assertItemsEqual(
            ["Shapefile should have exactly one feature (found 2)",
             "Missing required attributes ['Comment', 'XYZ_File']",
             "Unknown CRS {'init': u'epsg:4326'}, expected {'init': 'epsg:32756'} or {'init': 'epsg:32755'}",
             "Date in shapefile field SDate (20151029) inconsistent with file name date (20170601)",
             "Location in shapefile field (PortHackingBateBay) inconsistent with file name (BadShapefile)"
             ],
            pz.check_shapefile(shp_path, BAD_SURVEY_ZIP)
        )

    def test_corrupted_shapefile(self):
        shp_path = get_shp_path(CORRUPTED_SHP_ZIP)
        msg = pz.check_shapefile(shp_path, CORRUPTED_SHP_ZIP)
        self.assertEqual(1, len(msg))
        self.assertTrue(msg[0].startswith("Unable to open shapefile"))

    def test_check_zip_contents(self):
        report = pz.check_zip_contents(BAD_SURVEY_ZIP)
        self.assertIn("Zip file contents", report.keys())
        msg = report["Zip file contents"]
        self.assertRegexpMatches(msg[0], "^Not all files are for the same survey ")
        self.assertEqual("Missing bathymetry xyz file", msg[1])

    # TODO: test_get_dest_path


if __name__ == '__main__':
    unittest.main()
