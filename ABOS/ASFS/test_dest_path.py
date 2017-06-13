#!/usr/bin/env python
"""Unit tests for FileClassifier classes"""

import os
import shutil
import unittest
from tempfile import mkdtemp

from dest_path import SOFSFileClassifier
from test_file_classifier import make_test_file


class TestSOFSFileClassifier(unittest.TestCase):
    """Unit tests for ABOS/ASFS dest_path.py

    Test cases:
    * Sub-surface_currents
    * Sub-surface_temperature_pressure_conductivity
    * Surface_fluxes RT
    * Surface_fluxes DM
    * Surface_properties RT
    * Surface_properties DM
    * Surface_waves DM
    * Surface_waves RT

    Other cases including missing attributes, etc... are already
    tested in test_file_classifier

    """

    def setUp(self):
        self.tempdir = mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tempdir)

    def test_subsurface_currents(self):
        filename = 'IMOS_ABOS-ASFS_AETVZ_20130504T003015Z_SOFS_FV01_SOFS-4-2013-Workhorse-ADCP-500' \
                   '_END-20151212T000000Z_C-20140826T064252Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-12-12T00:00:00Z'},
                       UCUR={},
                       VCUR={},
                       WCUR={},
                       TEMP={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Sub-surface_currents')
        self.assertEqual(dest_filename, filename)

    def test_subsurface_ctd(self):
        filename = 'IMOS_ABOS-ASFS_CPT_20150101T000000Z_SOFS_FV01_100m_END-20151212T000000Z_C-20130225T042152Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-12-12T00:00:00Z'},
                       TEMP={},
                       CNDC={},
                       PRES={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Sub-surface_temperature_pressure_conductivity')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ABOS-ASFS_PT_20150101T000000Z_SOFS_FV01_VEMCO_END-20151212T000000Z_C-20130225T042157Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-12-12T00:00:00Z'},
                       TEMP={},
                       PRES={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Sub-surface_temperature_pressure_conductivity')
        self.assertEqual(dest_filename, filename)

    def test_waves_dm(self):
        filename = 'IMOS_ABOS-ASFS_RW_20150101T000000Z_SOFS_FV00_SOFS-2-2011-TriAXYS_END-20151212T000000Z' \
                   '_C-20140708T230346Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-12-12T00:00:00Z'},
                       DIR={},
                       HAV={},
                       HMAX={},
                       HM0={},
                       SIGMA_DIR={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_waves')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ABOS-ASFS_W_20150101T000000Z_SOFS_FV01_END-20151212T000000Z_C-20130207T035200Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-12-12T00:00:00Z'},
                       VAVH={},
                       DISP={},
                       FREQ={},
                       ACCEL_AVG={},
                       LOAD_CELL={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_waves')
        self.assertEqual(dest_filename, filename)

    def test_waves_rt(self):
        filename = 'IMOS_ABOS-ASFS_W_20150202T000000Z_SOFS_FV01_TriAXYS.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-01-01T23:30:00Z'},
                       HAV={},
                       HMAX={},
                       HSIG={},
                       TSIG={},
                       VDIR={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_waves/Real-time/2015_daily')
        self.assertEqual(dest_filename, filename)

    def test_surface_properties_dm(self):
        filename = \
            'IMOS_ABOS-ASFS_RTSCP_20150101T000000Z_SOFS_FV00_SOFS-3-2012_END-20151212T000000Z_C-20140730T112324Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-12-12T00:00:00Z'},
                       TEMP={},
                       PSAL={},
                       AIRT={},
                       RAIN={},
                       RELH={},
                       WSPD={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_properties')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ABOS-ASFS_CMST_20110101T000000Z_SOFS_FV01_1-min-avg_C-20120625T064508Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2011-01-01T00:00:00Z',
                        'time_coverage_end': '2011-01-01T23:59:00Z'},
                       TEMP={},
                       PSAL={},
                       AIRT={},
                       RAIN={},
                       RELH={},
                       WSPD={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_properties/2011_daily')
        self.assertEqual(dest_filename, filename)

    def test_surface_properties_rt(self):
        filename = 'IMOS_ABOS-ASFS_CMST_20150101T000000Z_SOFS_FV01_C-20160203T002503Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-01-01T23:30:00Z'},
                       TEMP={},
                       PSAL={},
                       AIRT={},
                       RAIN_AMOUNT={},
                       RELH={},
                       WSPD={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_properties/Real-time/2015_daily')
        self.assertEqual(dest_filename, filename)

    def test_surface_fluxes_dm(self):
        filename = \
            'IMOS_ABOS-ASFS_FMT_20150101T000000Z_SOFS_FV02_SOFS-1-2010_END-20151212T000000Z_C-20120906T022400Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-12-12T00:00:00Z'},
                       TEMP={},
                       PSAL={},
                       AIRT={},
                       HEAT_NET={},
                       MASS_NET={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_fluxes')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ABOS-ASFS_FMT_20110101T000000Z_SOFS_FV02_1-min-avg.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2011-01-01T00:00:00Z',
                        'time_coverage_end': '2011-01-01T23:59:00Z'},
                       TEMP={},
                       PSAL={},
                       AIRT={},
                       HEAT_NET={},
                       MASS_NET={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_fluxes/2011_daily')
        self.assertEqual(dest_filename, filename)

    def test_surface_fluxes_rt(self):
        filename = 'IMOS_ABOS-ASFS_FMT_20150101T000000Z_SOFS_FV02.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile,
                       {'time_coverage_start': '2015-01-01T00:00:00Z',
                        'time_coverage_end': '2015-01-01T23:30:00Z'},
                       TEMP={},
                       PSAL={},
                       AIRT={},
                       HEAT_NET={},
                       MASS_NET={}
                       )
        dest_dir, dest_filename = os.path.split(SOFSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/ASFS/SOFS/Surface_fluxes/Real-time/2015_daily')
        self.assertEqual(dest_filename, filename)


if __name__ == '__main__':
    unittest.main()
