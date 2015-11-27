#!/usr/bin/env python
"Unit tests for FileClassifier class"

import os
import unittest
from file_classifier import FileClassifier, FileClassifierException
from tempfile import mkstemp
from netCDF4 import Dataset


def make_test_file(filename, **attributes):
    ds = Dataset(filename, 'w')
    ds.setncatts(attributes)
    ds.close()


class TestFileClassifier(unittest.TestCase):

    def setUp(self):
        tmp_handle, self.testfile = mkstemp(prefix='IMOS_ANMN-NRS_', suffix='.nc')
        self.facility = 'ANMN'
        self.subfacility = 'NRS'
        self.fs = FileClassifier(self.facility, self.subfacility)

    def tearDown(self):
        os.remove(self.testfile)

    ### test methods

    def test_init(self):
        self.assertEqual(self.fs.facility, self.facility)
        self.assertEqual(self.fs.subfacility, self.subfacility)

    def test_get_subfacility(self):
        self.assertEqual(self.fs._get_subfacility(), self.subfacility)

    def test_get_nc_att(self):
        make_test_file(self.testfile, site_code='TEST1')
        self.assertEqual(self.fs._get_nc_att(self.testfile, 'site_code'), 'TEST1')
        self.assertRaises(FileClassifierException, self.fs._get_nc_att, self.testfile, 'missing')

    def test_get_site_code(self):
        make_test_file(self.testfile, site_code='TEST1')
        self.assertEqual(self.fs._get_site_code(self.testfile), 'TEST1')

    def test_dest_path(self):
        site_code='TEST1'
        make_test_file(self.testfile, site_code=site_code)
        correct_path = os.path.join(self.facility, self.subfacility, site_code)
        self.assertEqual(self.fs.dest_path(self.testfile), correct_path)

if __name__ == '__main__':
    unittest.main()
