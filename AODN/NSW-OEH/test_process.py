import os
import unittest
import zipfile

from process_zip import NSWOEHSurveyProcesor, is_date, check_crs, get_name_fields, get_survey_name, get_survey_methods

TEST_ROOT = os.path.join(os.path.dirname(__file__))
GOOD_MB_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20151029_PortHackingBateBay_MB.zip')
BAD_MB_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20170601_BadSurvey_MB.zip')
GOOD_STAX_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20111125_KingscliffBeach_STAX.zip')
BAD_STAX_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20170602_BadSurvey_STAX.zip')
CORRUPTED_SHP_ZIP = os.path.join(TEST_ROOT, 'NSWOEH_20111111_Corrupted_SHP.zip')


def get_shp_path(zipfile_path):
    """Return the path of a shapefile (.shp) within a zip file"""

    with zipfile.ZipFile(zipfile_path) as zf:
        path_list = zf.namelist()
    paths = [path for path in path_list if path.endswith('.shp')]

    assert len(paths) == 1, "Expected exactly 1 shapefile in zip, found {n}".format(n=len(paths))

    return '/' + paths[0]


class TestProcessZip(unittest.TestCase):
    proc = NSWOEHSurveyProcesor

    # @classmethod
    # def setUpClass(self):

    def test_is_date(self):
        self.assertTrue(is_date('20170601'))
        self.assertFalse(is_date('170601'))
        self.assertFalse(is_date('June2017'))
        self.assertFalse(is_date('2017-06-01'))
        self.assertFalse(is_date('17/06/01'))

    def test_check_crs(self):
        for crs in ('W84Z55', 'W84Z56'):
            self.assertListEqual(check_crs(crs), [])
        for crs in ('', 'NONE', 'W84Z42'):
            self.assertEqual(len(check_crs(crs)), 1)

    def test_get_name_fields(self):
        in_fld = ['one', 'two', 'three']
        fld, ext = get_name_fields('_'.join(in_fld))
        self.assertListEqual(in_fld, fld)
        self.assertEqual('', ext)

        in_fld = ['NSWOEH', '20151029', 'PortHackingBateBay', 'MB']
        in_ext = 'zip'
        fld, ext = get_name_fields('_'.join(in_fld) + '.' + in_ext)
        self.assertListEqual(in_fld, fld)
        self.assertEqual(in_ext, ext)

    def test_get_survey_name(self):
        self.assertEqual('20151029_PortHackingBateBay',
                         get_survey_name('NSWOEH_20151029_PortHackingBateBay_MB.shp'))
        self.assertEqual('20120921_TweedRiver',
                         get_survey_name('NSWOEH_20120921_TweedRiver_STAX_SHP.cpg'))
        self.assertEqual('', get_survey_name('NOT_NSWOEH_file.zip'))

    def test_get_survey_methods(self):
        self.assertEqual('MB', get_survey_methods('NSWOEH_20151029_PortHackingBateBay_MB.shp'))
        self.assertEqual('STAX', get_survey_methods('NSWOEH_20120921_TweedRiver_STAX_SHP.cpg'))
        self.assertEqual('', get_survey_methods('NOT_NSWOEH_file.zip'))
        self.assertEqual('', get_survey_methods('NSWOEH_file_bad.zip'))
        self.assertEqual('', get_survey_methods('NSWOEH_0151029_PortHackingBateBay_XYZ.zip'))

    def test_check_name_good_mb(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
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

    def test_check_name_wrong_date(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertEqual(['Wrong survey date 20011111 (zip file name has 20151029)'],
                         pz.check_name('NSWOEH_20011111_PortHackingBateBay_MB_SHP.shx')
                         )

    def test_check_name_wrong_location(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertEqual(['Wrong location TweedRiver (zip file name has PortHackingBateBay)'],
                         pz.check_name('NSWOEH_20151029_TweedRiver_MB_SHP.shx')
                         )

    def test_check_name_wrong_method(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertEqual(["Wrong survey method code STAX, expected MB"],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay_STAX_ScientificRigour.pdf')
                         )

    def test_check_name_short(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertEqual(["File name should have at least 4 underscore-separated fields."],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay.zip')
                         )

    def test_check_name_bad_method(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertEqual(["Field 4 should be a valid survey method code"],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay_BBB.zip')
                         )
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_STAX.zip')
        self.assertEqual(["Field 4 should be a valid survey method code"],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay_BBB.zip')
                         )

    def test_check_name_bad_rigour(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertEqual(["Unknown extension 'doc'",
                          "The Scientific Rigour (metadata) sheet must be in PDF format."],
                         pz.check_name('NSWOEH_20151029_PortHackingBateBay_MB_ScientificRigour.doc')
                         )

    def test_check_name_all_bad(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertItemsEqual(pz.check_name('IMOS_170202_N0-name_BBB.what'),
                              ["File name must start with 'NSWOEH'",
                               "Field 2 should be a valid date (YYYYMMDD).",
                               "Field 3 should be a location code consisting only of letters.",
                               "Field 4 should be a valid survey method code",
                               "Unknown extension 'what'",
                               "File name should have at least 5 underscore-separated fields."]
                              )

    # TODO: unittests for fields beyond the first 4

    def test_check_name_good_stax(self):
        pz = self.proc('NSWOEH_20111125_KingscliffBeach_STAX.zip')
        good_names = ['NSWOEH_20111125_KingscliffBeach_STAX_SHP.shx',
                      'NSWOEH_20111125_KingscliffBeach_STAX_RV12_AHD_MGA56_SEPT2012_TINMODEL_COVERAGE.dbf',
                      'NSWOEH_20111125_KingscliffBeach_STAX_2012_09_OEH_TWEED_RIVER_SURVEY.zip',
                      'NSWOEH_20111125_KingscliffBeach_STAX_56873s01.pdf',
                      'NSWOEH_20111125_KingscliffBeach_STAX_KingscliffBeach2011_AHD_MGA.xyz',
                      'NSWOEH_20111125_KingscliffBeach_STAX_KingscliffBeach2011.TXT',
                      'NSWOEH_20111125_KingscliffBeach_STAX_KingscliffBeach2011_AHD_MGA.sbn',
                      'NSWOEH_20111125_KingscliffBeach_STAX_log',
                      'NSWOEH_20111125_KingscliffBeach_STAX_schema.ini'
                      ]
        for name in good_names:
            msg = pz.check_name(name)
            self.assertEqual([], msg, "Unexpected messages for {name}:\n{msg}".format(name=name, msg=msg))

    def test_check_name_bad_stax(self):
        pz = self.proc('NSWOEH_20111125_KingscliffBeach_STAX.zip')
        self.assertItemsEqual(pz.check_name('IMOS_170202_N0-name_BBB.what'),
                              ["File name must start with 'NSWOEH'",
                               "Field 2 should be a valid date (YYYYMMDD).",
                               "Field 3 should be a location code consisting only of letters.",
                               "Field 4 should be a valid survey method code"]
                              )

    def test_check_name_spaces(self):
        pz = self.proc('NSWOEH_20120921_TweedRiver_STAX')
        self.assertEqual(
            pz.check_name('NSWOEH_20120921_TweedRiver_STAX_2012_09 OEH TWEED RIVER SURVEY.xyz'),
            ["File name should not contain spaces"]
        )

    def test_good_shapefile(self):
        pz = self.proc(GOOD_MB_ZIP)
        shp_path = get_shp_path(GOOD_MB_ZIP)
        self.assertEqual([], pz.check_shapefile(shp_path))

    def test_bad_shapefile(self):
        pz = self.proc(BAD_MB_ZIP)
        shp_path = get_shp_path(BAD_MB_ZIP)
        self.assertItemsEqual(
            ["Shapefile should have exactly one feature (found 2)",
             "Missing required attributes ['Comment', 'XYZ_File']",
             "Unknown CRS {'init': u'epsg:4326'}, expected {'init': 'epsg:32756'} or {'init': 'epsg:32755'}",
             "Date in shapefile field SDate (20151029) inconsistent with file name date (20170601)",
             "Location in shapefile field (PortHackingBateBay) inconsistent with file name (BadShapefile)"
             ],
            pz.check_shapefile(shp_path)
        )

    def test_corrupted_shapefile(self):
        pz = self.proc(CORRUPTED_SHP_ZIP)
        shp_path = get_shp_path(CORRUPTED_SHP_ZIP)
        msg = pz.check_shapefile(shp_path)
        self.assertEqual(1, len(msg))
        self.assertTrue(msg[0].startswith("Unable to open shapefile"))

    def test_check_all_good_mb(self):
        pz = self.proc(GOOD_MB_ZIP)
        self.assertDictEqual(pz.check_all(), dict())

    def test_check_all_good_stax(self):
        pz = self.proc(GOOD_STAX_ZIP)
        self.assertDictEqual(pz.check_all(), dict())

    def test_check_all_bad_mb(self):
        pz = self.proc(BAD_MB_ZIP)
        report = pz.check_all()
        self.assertItemsEqual(report["Zip file contents"], ["Missing bathymetry xyz file"])
        self.assertItemsEqual(report["NSWOEH_20151029_PortHackingBateBay_MB_ScientificRigour.pdf"],
                              ["Wrong survey date 20151029 (zip file name has 20170601)",
                               "Wrong location PortHackingBateBay (zip file name has BadSurvey)"
                               ]
                              )

    def test_check_all_bad_stax(self):
        pz = self.proc(BAD_STAX_ZIP)
        report = pz.check_all()
        self.assertItemsEqual(report["Zip file contents"],
                              ["Missing metadata file (PDF format)",
                               "Missing survey coverage shapefile"]
                              )
        self.assertItemsEqual(report["NSWOEH_20111125_KingscliffBeach_STAX_schema.ini"],
                              ["Wrong survey date 20111125 (zip file name has 20170602)",
                               "Wrong location KingscliffBeach (zip file name has BadSurvey)"
                               ]
                              )

    def test_get_dest_path(self):
        pz = self.proc('NSWOEH_20151029_PortHackingBateBay_MB.zip')
        self.assertEqual(pz.get_dest_path(), 'NSW-OEH/Multi-beam/2015/20151029_PortHackingBateBay')
        pz = self.proc('NSWOEH_20111125_KingscliffBeach_STAX.zip')
        self.assertEqual(pz.get_dest_path(), 'NSW-OEH/Single-beam/2011/20111125_KingscliffBeach')

    def test_get_dest_path_bad(self):
        pz = self.proc('NOTHING_GOOD.zip')
        with self.assertRaises(ValueError):
            pz.get_dest_path()


if __name__ == '__main__':
    unittest.main()
