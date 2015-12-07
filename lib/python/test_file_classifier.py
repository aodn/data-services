#!/usr/bin/env python
"Unit tests for FileClassifier class"

import os
import unittest
from file_classifier import FileClassifier, FileClassifierException
from tempfile import mkstemp
from netCDF4 import Dataset


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


class TestFileClassifier(unittest.TestCase):

    def setUp(self):
        tmp_handle, self.testfile = mkstemp(prefix='IMOS_ANMN-NRS_', suffix='.nc')

    def tearDown(self):
        os.remove(self.testfile)

    ### test methods

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

    def test_make_path(self):
        path = FileClassifier._make_path(['dir1', u'dir2', u'dir3'])
        self.assertTrue(isinstance(path, str))


if __name__ == '__main__':
    unittest.main()
