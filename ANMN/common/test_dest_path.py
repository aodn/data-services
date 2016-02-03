#!/usr/bin/env python

"""
Unit tests for ANMN dest_path.py

Test cases:
* Temperature loggers
* CTD_timeseries
* Biogeochem_timeseries
* Velocity (ADCP)
* Wave
* Biogeochem_profiles
* non-QC (FV00)
* burst-averaged
* gridded
* bad/unknonwn sub-facility
* missing site_code attribute
* missing featureType attribute

"""

import os
import unittest
from tempfile import mkdtemp
import shutil
from dest_path import ANMNFileClassifier, FileClassifierException
from test_file_classifier import make_test_file


class TestANMNFileClassifier(unittest.TestCase):


    def setUp(self):
        self.tempdir = mkdtemp()


    def tearDown(self):
        shutil.rmtree(self.tempdir)


    def test_temperature(self):
        filename = 'IMOS_ANMN-NSW_TZ_20150310T130000Z_PH100_FV01_PH100-1503-Aqualogger-520T-16_END-20150606T025000Z_C-20150804T234610Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'PH100', 'featureType':'timeSeries'},
                       TEMP={},
                       PRES={},
                       DEPTH={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NSW/PH100/Temperature')
        self.assertEqual(dest_filename, filename)


    def test_temperature_gridded(self):
        filename = 'IMOS_ANMN-NSW_Temperature_20100702T003500Z_CH070_FV02_CH070-1007-regridded_END-20100907T000500Z_C-20141211T025746Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'CH070', 'featureType':'timeSeriesProfile'},
                       TEMP={},
                       DEPTH={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NSW/CH070/Temperature/gridded')
        self.assertEqual(dest_filename, filename)


    def test_ctd_timeseries(self):
        filename = 'IMOS_ANMN-WA_CSTZ_20141117T080001Z_WATR10_FV01_WATR10-1411-SBE37SM-RS232-52.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'WATR10', 'featureType':'timeSeries'},
                       TEMP={},
                       PRES={},
                       CNDC={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/WA/WATR10/CTD_timeseries')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ANMN-SA_ACESTZ_20141201T030411Z_SAM8SG-1412_FV01_SAM8SG-1412-NXIC-CTD-44.71_END-20150411T020421Z_C-20150730T044018Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'SAM8SG', 'featureType':'timeSeries'},
                       TEMP={},
                       PRES_REL={},
                       DEPTH={},
                       PSAL={},
                       CNDC={},
                       SSPD={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/SA/SAM8SG/CTD_timeseries')
        self.assertEqual(dest_filename, filename)


    def test_bgc_timeseries(self):
        filename = 'IMOS_ANMN-NRS_KOSTUZ_20150330T080039Z_NRSROT_FV01_NRSROT-1503-WQM-55_END-20150727T063234Z_C-20150731T040136Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSROT', 'featureType':'timeSeries'},
                       TEMP={},
                       PRES_REL={},
                       DEPTH={},
                       PSAL={},
                       DOX2={},
                       CPHL={},
                       TURB={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSROT/Biogeochem_timeseries')
        self.assertEqual(dest_filename, filename)


    def test_burst_averaged(self):
        filename = 'IMOS_ANMN-NRS_KOSTUZ_20140808T080100Z_NRSROT_FV02_NRSROT-1408-WQM-55-burst-averaged_END-20141215T234700Z_C-20150319T075400Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSROT', 'featureType':'timeSeries'},
                       TEMP={},
                       PRES_REL={},
                       DEPTH={},
                       PSAL={},
                       DOX2={},
                       CPHL={},
                       TURB={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSROT/Biogeochem_timeseries/burst-averaged')
        self.assertEqual(dest_filename, filename)


    def test_velocity(self):
        filename = 'IMOS_ANMN-NRS_AETVZ_20150703T053000Z_NRSROT-ADCP_FV01_NRSROT-ADCP-1507-Workhorse-ADCP-43_END-20151023T034500Z_C-20151117T074309Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSROT', 'featureType':'timeSeriesProfile'},
                       TEMP={},
                       PRES_REL={},
                       DEPTH={},
                       UCUR={},
                       VCUR={},
                       WCUR={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSROT/Velocity')
        self.assertEqual(dest_filename, filename)


    def test_wave(self):
        filename = 'IMOS_ANMN-NRS_WZ_20140914T075900Z_NRSDAR_FV01_NRSDAR-1409-SUB-Workhorse-ADCP-24.3_END-20150205T225900Z_C-20150326T055936Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSDAR', 'featureType':'doesntmatter'},
                       DEPTH={},
                       VAVH={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSDAR/Wave')
        self.assertEqual(dest_filename, filename)


    def test_bgc_profiles(self):
        filename = 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_NRSMAI_FV01_Profile-SBE-19plus_C-20151030T034432Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSMAI', 'featureType':'profile'})
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSMAI/Biogeochem_profiles')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ANMN-WA_CDEKOSTUZ_20121113T013800Z_WACA20_FV01_3052.0-1-SBE19plus-70_C-20140211T090215Z'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'WACA20', 'featureType':'profile'})
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/WA/WACA20/Biogeochem_profiles')
        self.assertEqual(dest_filename, filename)


    def test_nonqc(self):
        filename = 'IMOS_ANMN-NSW_TZ_20150310T130000Z_PH100_FV00_PH100-1503-Aqualogger-520T-16_END-20150606T025000Z_C-20150804T234610Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'site_code':'PH100', 'featureType':'timeSeries', 'file_version':'Level 0 - Raw data'},
                       TEMP={},
                       PRES={},
                       DEPTH={}
        )
        dest_dir, dest_filename = os.path.split(ANMNFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NSW/PH100/Temperature/non-QC')
        self.assertEqual(dest_filename, filename)


    def test_bad_subfacility(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-BAD_CDEKOSTUZ_20121113T001841Z_BADBAD_FV01_Profile.nc')
        make_test_file(testfile, {'site_code':'NRSMAI'})
        with self.assertRaises(FileClassifierException) as e:
            ANMNFileClassifier.dest_path(testfile)
        self.assertIn('Invalid sub-facility', e.exception.args[0])


    def test_missing_subfacility(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN_CDEKOSTUZ_20121113T001841Z_BADBAD_FV01_Profile.nc')
        make_test_file(testfile)
        with self.assertRaises(FileClassifierException) as e:
            ANMNFileClassifier.dest_path(testfile)
        self.assertIn('Could not extract sub-facility', e.exception.args[0])


    def test_missing_site_code(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_BADBAD_FV01_Profile.nc')
        make_test_file(testfile)
        with self.assertRaises(FileClassifierException) as e:
            ANMNFileClassifier.dest_path(testfile)
        self.assertIn("has no attribute 'site_code'", e.exception.args[0])


    def test_missing_featuretype(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_NRSMAI_FV01_Profile-SBE-19plus_C-20151030T034432Z.nc')
        make_test_file(testfile, {'site_code':'NRSMAI'})
        with self.assertRaises(FileClassifierException) as e:
            ANMNFileClassifier.dest_path(testfile)
        self.assertIn("has no attribute 'featureType'", e.exception.args[0])



if __name__ == '__main__':
    unittest.main()
