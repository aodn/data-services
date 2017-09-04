#!/usr/bin/env python
"""Unit tests for ABOSFileClassifier class"""

import os
import shutil
import unittest
from tempfile import mkdtemp

from dest_path import ABOSFileClassifier, FileClassifierException
from test_file_classifier import make_test_file


class TestABOSFileClassifier(unittest.TestCase):
    """Unit tests for ABOS dest_path.py

    Test cases:
    * DA Temperature loggers
    * DA CTD_timeseries
    * DA Biogeochem_timeseries
    * DA Velocity (ADCP)
    * SOTS/SAZ CTD_timeseries
    * SOTS/SAZ Velocity
    * SOTS/SAZ Sediment_traps
    * Pulse DM
    * Pulse RT
    * FluxPulse RT

    Other cases including missing attributes, etc... are already
    tested in test_file_classifier

    """

    def setUp(self):
        self.tempdir = mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tempdir)

    def test_da_temperature(self):
        filename = 'IMOS_ABOS-DA_TZ_20120426T092000Z_EAC5_FV01_EAC5-2012-STARMON-MINI-300_END-20130826T222000Z_C' \
                   '-20140722T061401Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'platform_code': 'EAC5', 'featureType': 'timeSeries'},
                       TEMP={},
                       DEPTH={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/DA/EAC5/Temperature')
        self.assertEqual(dest_filename, filename)

    def test_da_ctd_timeseries(self):
        filename = 'IMOS_ABOS-DA_STZ_20120426T092000Z_EAC5_FV01_EAC5-2012-SBE37SMP-202_END-20130826T222000Z_C' \
                   '-20140722T061531Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'platform_code': 'EAC5', 'featureType': 'timeSeries'},
                       TEMP={},
                       PSAL={},
                       PRES_REL={},
                       DEPTH={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/DA/EAC5/CTD_timeseries')
        self.assertEqual(dest_filename, filename)

    def test_sots_ctd_timeseries(self):
        filename = 'IMOS_ABOS-SOTS_20120718T052204Z_SAZ_FV01_SAZ-15-microcat-4422m-2012_END-20131008T190000Z_C' \
                   '-20131216T221210Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code': 'SOTS', 'platform_code': 'SAZ47'},
                       DEPTH_CN_PR_PS_TE={},
                       CNDC={},
                       PRES={},
                       PSAL={},
                       TEMP={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/SOTS/SAZ47/CTD_timeseries')
        self.assertEqual(dest_filename, filename)

    def test_da_bgc_timeseries(self):
        filename = 'IMOS_ABOS-DA_CEOSTZ_20140218T000057Z_TOTTEN1_FV01_TOTTEN1-SBE37SMP-ODO-9880_END' \
                   '-20150103T230035Z_C-20160112T020000Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'platform_code': 'TOTTEN1', 'featureType': 'timeSeries'},
                       TEMP={},
                       PRES={},
                       PSAL={},
                       CNDC={},
                       DOX1={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/DA/TOTTEN1/Biogeochem_timeseries')
        self.assertEqual(dest_filename, filename)

    def test_da_velocity(self):
        filename = 'IMOS_ABOS-DA_AETVZ_20140204T000000Z_TOTTEN1_FV01_TOTTEN1-WORKHORSE-ADCP-14489_END' \
                   '-20150103T224000Z_C-20160112T020000Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'platform_code': 'TOTTEN1', 'featureType': 'timeSeries'},
                       UCUR={},
                       VCUR={},
                       WCUR={},
                       ECUR={},
                       CSPD={},
                       CDIR={},
                       TEMP={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/DA/TOTTEN1/Velocity')
        self.assertEqual(dest_filename, filename)

    def test_sots_velocity(self):
        filename = 'IMOS_ABOS-SOTS_AETVZ_20100912T224200Z_SAZ47_FV01_SAZ47-13-2010-Aquadopp-Current-Meter-1100_END' \
                   '-20110804T053000Z_C-20140826T062213Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'featureType': 'timeSeries', 'site_code': 'SOTS', 'platform_code': 'SAZ47'},
                       VCUR={},
                       UCUR={},
                       WCUR={},
                       TEMP={},
                       PRES_REL={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/SOTS/SAZ47/Velocity')
        self.assertEqual(dest_filename, filename)

    def test_sots_sediment_traps(self):
        filename = 'IMOS_ABOS-SOTS_RFK_20120724T000000Z_SAZ47_FV01_SAZ47-2012Sediment-Trap-Data_20130828T000000Z_C' \
                   '-20150210T043901Z.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'featureType': 'timeSeries', 'site_code': 'SOTS', 'platform_code': 'SAZ47'},
                       DEPTH={},
                       MASS_FLUX={},
                       CACO3={},
                       PIC={},
                       PC={},
                       N={},
                       POC={},
                       BSIO2={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/SOTS/SAZ47/Sediment_traps')
        self.assertEqual(dest_filename, filename)

    def test_pulse_delayed(self):
        filename = 'IMOS_ABOS-SOTS_20130507T080000Z_Pulse_FV01_Pulse-10-2013_END-20131013T210000Z_C-20160315T000000Z.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code': 'SOTS', 'platform_code': 'Pulse'},
                       TEMP={},
                       PRES={},
                       PSAL={},
                       CNDC={},
                       DOX2={},
                       CPHL={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/SOTS/Pulse')
        self.assertEqual(dest_filename, filename)

    def test_pulse_realtime(self):
        filename = 'IMOS_ABOS-SOTS_W_20150325T110000Z_Pulse_FV00_Pulse-11-2015-MRU-Surface-wave-height-realtime.nc'
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code': 'SOTS', 'platform_code': 'Pulse'},
                       VAVH={},
                       DISP={},
                       ACCEL_AVG={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/SOTS/Pulse/real-time')
        self.assertEqual(dest_filename, filename)

    def test_fluxpulse_realtime(self):
        filename = 'IMOS_ABOS-SOTS_W_20160316T140000Z_FluxPulse_FV00_FluxPulse-1-2016-MRU-Surface-wave-height' \
                   '-realtime.nc '
        testfile = os.path.join(self.tempdir, filename)
        make_test_file(testfile, {'site_code': 'SOTS', 'platform_code': 'FluxPulse'},
                       VAVH={},
                       DISP={},
                       FREQ={}
                       )
        dest_dir, dest_filename = os.path.split(ABOSFileClassifier.dest_path(testfile))
        self.assertEqual(dest_dir, 'IMOS/ABOS/SOTS/FluxPulse/real-time')
        self.assertEqual(dest_filename, filename)


if __name__ == '__main__':
    unittest.main()
