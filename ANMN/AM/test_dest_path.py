"""Unit tests for ANMN AM dest_path.py

Input: 
  incoming netCDF file

Output:
  relative path where file should go, e.g. NRSMAI/CO2/delayed/
  ('IMOS/ANMN/AM' is prepended in incoming_handler)

Assume: (will be checked by handler)
 * File is netCDF
 * File belongs to ANMN-AM

Test cases:
1) correct delayed-mode file
2) correct real-time file
3) can't determine real-time or delayed mode
4) missing site_code

"""

import os
import unittest
from tempfile import mkdtemp
from dest_path import AnmnAmFileClassifier, FileClassifierException
from test_file_classifier import make_test_file


class TestAnmnAmFileClassifier(unittest.TestCase):

    def setUp(self):
        self.tempdir = mkdtemp()
        self.fs = AnmnAmFileClassifier()

    def tearDown(self):
        for testfile in os.listdir(self.tempdir):
            os.remove( os.path.join(self.tempdir, testfile) )
        os.rmdir(self.tempdir)

    def test_delayed_mode(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-AM_GST_20140923T060000Z_NRSMAI_FV01_NRSMAI-CO2-1409-delayed_END_20150422T220000Z_C-20150625T151716Z.nc')
        make_test_file(testfile, site_code='NRSMAI')
        self.assertEqual(self.fs.dest_path(testfile), 'NRSMAI/CO2/delayed')

    def test_realtime(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-AM_KST_20151116T220001Z_NRSKAI_FV00_NRSKAI-CO2-1511-realtime-raw_END-20151116T220001Z_C-20151117T214013Z.nc')
        make_test_file(testfile, site_code='NRSKAI')
        self.assertEqual(self.fs.dest_path(testfile), 'NRSKAI/CO2/real-time')

    def test_neither_type(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-AM_KST_20151116T220001Z_NRSKAI_FV00.nc')
        make_test_file(testfile, site_code='NRSKAI')
        self.assertRaises(FileClassifierException, self.fs.dest_path, testfile)

    def test_missing_site_code(self):
        testfile = os.path.join(self.tempdir, 'IMOS_ANMN-AM_KST_20151116T220001Z_NRSKAI_FV00_NRSKAI-CO2-1511-realtime-raw.nc')
        make_test_file(testfile)
        self.assertRaises(FileClassifierException, self.fs.dest_path, testfile)
