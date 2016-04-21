#!/usr/bin/env python

"""
Unit tests for ANMN previous_versions.py

Test cases:
* dest_dir doesn't exist
* no prev. versionss
* 1 prev. version
* prev. version with different instrument name
* matching names but non-matching attributes
* missing attributes in new file
* missing attributes in prev files
* burst-averaged product (FV02, but treat same as other files)
* Temp gridded product (no serial number, only need to match deployment code)
* CTD profile (match based on site_code, cruise and time_coverage_start)
* new file is older than prev file
* new file has same creation date as prev file (probably same file)
"""

import unittest
import os
import sys
from StringIO import StringIO
from tempfile import mkdtemp
import shutil
from test_file_classifier import make_test_file
from previous_versions import FileMatcher, FileMatcherException


class TestFileMatcher(unittest.TestCase):

    def setUp(self):
        self.incoming_dir = mkdtemp()
        self.dest_dir = mkdtemp()

        self.old_file1 = os.path.join(self.dest_dir, 'IMOS_ANMN-NRS_TZ_20120928T030000Z_NRSROT_FV01_NRSROT-1209-SBE39-27_END-20130125T032500Z_C-20130131T000000Z.nc')
        make_test_file(self.old_file1, {'deployment_code' : 'NRSROT-1209', 
                                        'instrument_serial_number' : '1',
                                        'date_created' : '2013-01-31T00:00:00Z'})

        self.old_file2 = os.path.join(self.dest_dir, 'IMOS_ANMN-NRS_TZ_20120928T030000Z_NRSROT_FV01_NRSROT-1209-SBE39-33_END-20130125T032500Z_C-20130131T000000Z.nc')
        make_test_file(self.old_file2, {'deployment_code' : 'NRSROT-1209', 
                                        'instrument_serial_number' : '2',
                                        'date_created' : '2013-01-31T00:00:00Z'})

        self.old_file3 = os.path.join(self.dest_dir, 'IMOS_ANMN-NRS_TZ_20130125T043000Z_NRSROT_FV01_NRSROT-1301-SBE39-27_END-20130517T033000Z_C-20130522T041119Z.nc')
        make_test_file(self.old_file3, {'deployment_code' : 'NRSROT-1301',
                                        'instrument_serial_number' : '1',
                                        'date_created' : '2013-05-22T04:11:19Z'})

        self.old_grid_file = os.path.join(self.dest_dir, 'IMOS_ANMN-NSW_Temperature_20100702T003500Z_CH070_FV02_CH070-1007-regridded_END-20100907T000500Z_C-20130522T041119Z.nc')
        make_test_file(self.old_grid_file, {'deployment_code' : 'CH070-1007',
                                            'date_created' : '2013-05-22T04:11:19Z'})

        self.old_burst_file = os.path.join(self.dest_dir, 'IMOS_ANMN-NRS_KOSTUZ_20140808T080100Z_NRSROT_FV02_NRSROT-1408-WQM-55-burst-averaged_END-20141215T234700Z_C-20140319T075400Z.nc')
        make_test_file(self.old_burst_file, {'deployment_code' : 'NRSROT-1408',
                                             'instrument_serial_number' : 'WQM01',
                                             'date_created' : '2014-03-19T07:54:00Z'})

        self.old_profile1 = os.path.join(self.dest_dir, 'IMOS_ANMN-NRS_CDEKOSTUZ_20150507T020208Z_NRSROT_FV01_Profile-SBE19plus_C-20150508T022249Z.nc')
        make_test_file(self.old_profile1, {'featureType' : 'profile',
                                           'site_code' : 'NRSROT',
                                           'cruise' : '3086',
                                           'time_coverage_start' : '2015-05-07T02:02:08Z',
                                           'date_created' : '2015-05-08T02:22:49Z'})

        self.old_profile2 = os.path.join(self.dest_dir, 'IMOS_ANMN-NRS_CDEKOSTUZ_20150701T020830Z_NRSROT_FV01_Profile-SBE19plus_C-20150702T023326Z.nc')
        make_test_file(self.old_profile2, {'featureType' : 'profile',
                                           'site_code' : 'NRSROT',
                                           'cruise' : '3087',
                                           'time_coverage_start' : '2015-07-01T02:08:30Z',
                                           'date_created' : '2015-07-02T02:33:26Z'})


    def tearDown(self):
        shutil.rmtree(self.incoming_dir)
        shutil.rmtree(self.dest_dir)


    def test_new_dest_dir(self):
        new_dest_dir = mkdtemp()
        os.rmdir(new_dest_dir)
        new_file = 'new_file.nc'

        # redirect stderr so we can check the warning message
        err = StringIO()
        sys.stderr = err
        self.assertEqual(FileMatcher.previous_versions(new_file , new_dest_dir), [])
        sys.stderr = sys.__stderr__
        self.assertEqual(err.getvalue(), 
                         "Destination path '%s' for '%s' does not exist\n" % (new_dest_dir, new_file))
        err.close()


    def test_no_previous_versions(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_TZ_20140125T043000Z_NRSROT_FV01_NRSROT-1401-SBE39-33_END-20140517T033000Z_C-20150522T041119Z.nc')
        make_test_file(new_file, {'deployment_code' : 'NRSROT-1401', 
                                  'instrument_serial_number' : '2',
                                  'date_created' : '2015-05-22T04:11:19Z'})
        self.assertEqual(FileMatcher.previous_versions(new_file , self.dest_dir), [])
       

    def test_good_previous_version(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_TZ_20120928T031111Z_NRSROT_FV01_NRSROT-1209-SBE39-28.5_END-20130125T032500Z_C-20160101T000000Z.nc')
        make_test_file(new_file, {'deployment_code' : 'NRSROT-1209',
                                  'instrument_serial_number' : '1',
                                  'date_created' : '2016-01-01T00:00:00Z'})
        self.assertEqual(FileMatcher.previous_versions(new_file , self.dest_dir), [self.old_file1])


    def test_different_instrument_name(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_TZ_20120928T031111Z_NRSROT_FV01_NRSROT-1209-SBE39-special-edition-28.5_END-20130125T032500Z_C-20160101T000000Z.nc')
        make_test_file(new_file, {'deployment_code' : 'NRSROT-1209',
                                  'instrument_serial_number' : '1',
                                  'date_created' : '2016-01-01T00:00:00Z'})
        self.assertEqual(FileMatcher.previous_versions(new_file , self.dest_dir), [self.old_file1])


    def test_burst_averaged(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_KOSTUZ_20140808T080100Z_NRSROT_FV02_NRSROT-1408-WQM-55-burst-averaged_END-20141215T234700Z_C-20150319T075400Z.nc')
        make_test_file(new_file, {'deployment_code' : 'NRSROT-1408',
                                  'instrument_serial_number' : 'WQM01',
                                  'date_created' : '2015-03-19T07:54:00Z'})
        self.assertEqual(FileMatcher.previous_versions(new_file , self.dest_dir), [self.old_burst_file])


    def test_no_matching_attributes(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_TZ_20120928T031111Z_NRSROT_FV01_NRSROT-1209-SBE39-55_END-20130125T032500Z_C-20160101T000000Z.nc')
        make_test_file(new_file, {'deployment_code' : 'NRSROT-1209',
                                  'instrument_serial_number' : '77',
                                  'date_created' : '2016-01-01T00:00:00Z'})
        self.assertEqual(FileMatcher.previous_versions(new_file , self.dest_dir), [])


    def test_missing_attributes(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_TZ_20120928T031111Z_NRSROT_FV01_NRSROT-1209-SBE39-28_END-20130125T032500Z_C-20160101T000000Z.nc')
        make_test_file(new_file, {'deployment_code' : 'NRSROT-1209',
                                  'date_created' : '2016-01-01T00:00:00Z'})        
        with self.assertRaises(FileMatcherException) as e:
            pv = FileMatcher.previous_versions(new_file , self.dest_dir)
        self.assertIn("has no attribute 'instrument_serial_number'", e.exception.args[0])


    def test_temperature_gridded(self):
        new_file =  os.path.join(self.incoming_dir, 'IMOS_ANMN-NSW_Temperature_20100702T003500Z_CH070_FV02_CH070-1007-regridded_END-20100907T000500Z_C-20141211T000000Z.nc')
        make_test_file(new_file, {'deployment_code' : 'CH070-1007',
                                  'date_created' : '2014-12-11T00:00:00Z'})
        self.assertEqual(FileMatcher.previous_versions(new_file , self.dest_dir), [self.old_grid_file])


    def test_profile(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_CDEKOSTUZ_20150701T020830Z_NRSROT_FV01_Profile-SBE19plus_C-20160101T000000Z.nc')
        make_test_file(new_file, {'featureType' : 'profile',
                                  'site_code' : 'NRSROT',
                                  'cruise' : '3087',
                                  'time_coverage_start' : '2015-07-01T02:08:30Z',
                                  'date_created' : '2016-01-01T00:00:00Z'})
        self.assertEqual(FileMatcher.previous_versions(new_file , self.dest_dir), [self.old_profile2])


    def test_new_file_is_older(self):
        new_file = os.path.join(self.incoming_dir, 'IMOS_ANMN-NRS_TZ_20120928T031111Z_NRSROT_FV01_NRSROT-1209-SBE39-28.5_END-20130125T032500Z_C-20120101T000000Z.nc')
        make_test_file(new_file, {'deployment_code' : 'NRSROT-1209', 
                                  'instrument_serial_number' : '1',
                                  'date_created' : '2012-01-01T00:00:00Z'})
        with self.assertRaises(FileMatcherException) as e:
            pv = FileMatcher.previous_versions(new_file , self.dest_dir)
        self.assertIn("is not newer than previously published version", e.exception.args[0])
        self.assertIn(self.old_file1, e.exception.args[0])

    def test_new_file_same_as_old_file(self):
        self.assertEqual(FileMatcher.previous_versions(self.old_file1 , self.dest_dir), [self.old_file1])


if __name__ == '__main__':
    unittest.main()
