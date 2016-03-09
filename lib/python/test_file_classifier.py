#!/usr/bin/env python
"Unit tests for FileClassifier classes"

import os
import unittest
from file_classifier import FileClassifier, MooringFileClassifier, FileClassifierException
from tempfile import mkstemp, mkdtemp
from netCDF4 import Dataset
import shutil


### Util function

def make_test_file(filename, attributes={}, **variables):
    """Create a netcdf file with the given global and variable
    attributes. Variables are created as dimensionless doubles.

    For example this:

        make_test_file(testfile,
                       {'title':'test file', 'site_code':'NRSMAI'},
                       TEMP = {'standard_name':'sea_water_temperature'},
                       PSAL = {'standard_name':'sea_water_salinity'}
        )

    will create (in cdl):

        netcdf testfile {
        variables:
            double PSAL ;
                    PSAL:standard_name = "sea_water_salinity" ;
            double TEMP ;
                    TEMP:standard_name = "sea_water_temperature" ;

        // global attributes:
                    :site_code = "NRSMAI" ;
                    :title = "test file" ;
        }

    """
    ds = Dataset(filename, 'w')
    ds.setncatts(attributes)
    for name, adict in variables.iteritems():
        var = ds.createVariable(name, float)
        var.setncatts(adict)
    ds.close()



### Test classes

class TestFileClassifier(unittest.TestCase):

    def setUp(self):
        tmp_handle, self.testfile = mkstemp(prefix='IMOS_ANMN-NRS_', suffix='.nc')

    def tearDown(self):
        os.remove(self.testfile)

    ### test methods

    def test_get_file_name_fields(self):
        filename = 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_NRSMAI_FV01_Profile-SBE-19plus.nc'
        fields = ['IMOS', 'ANMN-NRS', 'CDEKOSTUZ', '20121113T001841Z', 'NRSMAI', 'FV01', 'Profile-SBE-19plus']
        self.assertEqual(FileClassifier._get_file_name_fields(filename), fields)
        filename = 'IMOS_ANMN-NRS_20110203_NRSPHB_FV01_LOGSHT.pdf'
        fields = ['IMOS', 'ANMN-NRS', '20110203', 'NRSPHB', 'FV01', 'LOGSHT']
        self.assertEqual(FileClassifier._get_file_name_fields(filename), fields)
        with self.assertRaises(FileClassifierException) as e:
            FileClassifier._get_file_name_fields('bad_file_name', min_fields=4)
        self.assertIn('has less than 4 fields in file name', e.exception.args[0])

    def test_get_facility(self):
        filename = 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_NRSMAI_FV01_Profile-SBE-19plus.nc'
        self.assertEqual(FileClassifier._get_facility(filename), ('ANMN', 'NRS'))
        with self.assertRaises(FileClassifierException) as e:
            FileClassifier._get_facility('IMOS_NO_SUB_FACILITY.nc')
        self.assertIn('Missing sub-facility in file name', e.exception.args[0])

    def test_bad_file(self):
        self.assertRaises(FileClassifierException, FileClassifier._get_nc_att, self.testfile, 'attribute')

    def test_get_nc_att(self):
        make_test_file(self.testfile, {'site_code':'TEST1', 'title':'Test file'})
        self.assertEqual(FileClassifier._get_nc_att(self.testfile, 'site_code'), 'TEST1')
        self.assertEqual(FileClassifier._get_nc_att(self.testfile, 'missing', ''), '')
        self.assertEqual(FileClassifier._get_nc_att(self.testfile, ['site_code', 'title']),
                         ['TEST1', 'Test file'])
        self.assertRaises(FileClassifierException, FileClassifier._get_nc_att, self.testfile, 'missing')

    def test_get_site_code(self):
        make_test_file(self.testfile, {'site_code':'TEST1'})
        self.assertEqual(FileClassifier._get_site_code(self.testfile), 'TEST1')

    def test_get_variable_names(self):
        make_test_file(self.testfile, {}, PRES={}, TEMP={}, PSAL={})
        output = set(FileClassifier._get_variable_names(self.testfile))
        self.assertEqual(output, set(['PRES', 'TEMP', 'PSAL']))

    def test_make_path(self):
        path = FileClassifier._make_path(['dir1', u'dir2', u'dir3'])
        self.assertTrue(isinstance(path, str))



class TestMooringFileClassifier(unittest.TestCase):
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
    * missing site_code attribute
    * missing featureType attribute

    """


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
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NSW/PH100/Temperature')
        self.assertEqual(dest_filename, filename)


    def test_pressure_only(self):
        # Files will only pressure are also classified as "Temperature".
        filename = 'IMOS_ANMN-WA_Z_20120914T032100Z_WATR50_FV01_WATR50-1209-DR-1050-517_END-20130319T053000Z_C-20130325T032512Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'WATR50', 'featureType':'timeSeries'},
                       PRES={},
                       DEPTH={}
        )
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/WA/WATR50/Temperature')
        self.assertEqual(dest_filename, filename)


    def test_temperature_gridded(self):
        filename = 'IMOS_ANMN-NSW_Temperature_20100702T003500Z_CH070_FV02_CH070-1007-regridded_END-20100907T000500Z_C-20141211T025746Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'CH070', 'featureType':'timeSeriesProfile'},
                       TEMP={},
                       DEPTH={}
        )
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
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
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
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
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
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
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
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
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSROT/Biogeochem_timeseries/burst-averaged')
        self.assertEqual(dest_filename, filename)


    def test_velocity(self):
        filename = 'IMOS_ANMN-NRS_AETVZ_20150703T053000Z_NRSROT-ADCP_FV01_NRSROT-ADCP-1507-Workhorse-ADCP-43_END-20151023T034500Z_C-20151117T074309Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSROT'},
                       TEMP={},
                       PRES_REL={},
                       DEPTH={},
                       UCUR={},
                       VCUR={},
                       WCUR={}
        )
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSROT/Velocity')
        self.assertEqual(dest_filename, filename)


    def test_wave(self):
        filename = 'IMOS_ANMN-NRS_WZ_20140914T075900Z_NRSDAR_FV01_NRSDAR-1409-SUB-Workhorse-ADCP-24.3_END-20150205T225900Z_C-20150326T055936Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSDAR', 'featureType':'doesntmatter'},
                       DEPTH={},
                       VAVH={}
        )
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSDAR/Wave')
        self.assertEqual(dest_filename, filename)


    def test_bgc_profiles(self):
        filename = 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_NRSMAI_FV00_Profile-SBE-19plus_C-20151030T034432Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSMAI', 'featureType':'profile'},
                       TEMP={},
                       PRES={},
                       CNDC={}
        )
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSMAI/Biogeochem_profiles/non-QC')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ANMN-WA_CDEKOSTUZ_20121113T013800Z_WACA20_FV01_3052.0-1-SBE19plus-70_C-20140211T090215Z'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'WACA20', 'featureType':'profile'},
                       TEMP={},
                       PRES_REL={},
                       PSAL={},
                       DOX2={}
        )
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/WA/WACA20/Biogeochem_profiles')
        self.assertEqual(dest_filename, filename)


    def test_unknown_profiles(self):
        filename = 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_NRSMAI_FV00_mystery-profile.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code':'NRSMAI', 'featureType':'profile'},
                       TIME={},
                       DEPTH={}
        )
        with self.assertRaises(FileClassifierException) as e:
            MooringFileClassifier.dest_path(testfile)
        self.assertIn("Could not determine data category", e.exception.args[0])


    def test_nonqc(self):
        filename = 'IMOS_ANMN-NSW_TZ_20150310T130000Z_PH100_FV00_PH100-1503-Aqualogger-520T-16_END-20150606T025000Z_C-20150804T234610Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'site_code':'PH100', 'featureType':'timeSeries', 'file_version':'Level 0 - Raw data'},
                       TEMP={},
                       PRES={},
                       DEPTH={}
        )
        dest_dir, dest_filename = os.path.split(MooringFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NSW/PH100/Temperature/non-QC')
        self.assertEqual(dest_filename, filename)


    def test_missing_site_code(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_BADBAD_FV01_Profile.nc')
        make_test_file(testfile)
        with self.assertRaises(FileClassifierException) as e:
            MooringFileClassifier.dest_path(testfile)
        self.assertIn("has no attribute 'site_code'", e.exception.args[0])


    def test_missing_featuretype(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-NRS_CDEKOSTUZ_20121113T001841Z_NRSMAI_FV01_Profile-SBE-19plus_C-20151030T034432Z.nc')
        make_test_file(testfile, {'site_code':'NRSMAI'})
        with self.assertRaises(FileClassifierException) as e:
            MooringFileClassifier.dest_path(testfile)
        self.assertIn("has no attribute 'featureType'", e.exception.args[0])


if __name__ == '__main__':
    unittest.main()
