#!/usr/bin/env python3
"""
unittest for lib/common/utils.py

author : besnard, laurent
"""

import os
import shutil
from pandas import Timestamp
import unittest
import tempfile
from ardc_nrt.lib.common.pickle_db import ardcPickle

TEST_ROOT = os.path.dirname(__file__)
NC_FILE = os.path.join(TEST_ROOT, 'OMC_W_B10_20220301T000000Z_monthly_FV00.nc')


class TestLookup(unittest.TestCase):
    def setUp(self):
        self.pickle_test_dir = tempfile.mkdtemp()
        shutil.copy(os.path.join(TEST_ROOT, 'pickle.db'), self.pickle_test_dir)

    def tearDown(self):
        shutil.rmtree(self.pickle_test_dir)

    def test_load(self):
        val = ardcPickle('/DUMMY').load()
        self.assertEqual(None, val)

        val = ardcPickle(self.pickle_test_dir).load()
        self.assertTrue('SPOT-0278' in val.keys())

    def test_get_latest_processed_date(self):
        val = ardcPickle(self.pickle_test_dir).get_latest_processed_date('DUMMY')
        self.assertEqual(None, val)

        val = ardcPickle('/DUMMY').get_latest_processed_date('DUMMY')
        self.assertEqual(None, val)

        val = ardcPickle(self.pickle_test_dir).get_latest_processed_date('SPOT-0278')
        self.assertEqual(Timestamp('2021-09-30 22:20:01+0000', tz='UTC'), val)

    def test_save(self):
        data = ardcPickle(self.pickle_test_dir).load()
        val = ardcPickle(self.pickle_test_dir).save(data)
        self.assertEqual(None, val)

    def test_save_latest_download_success(self):
        val = ardcPickle(self.pickle_test_dir).save_latest_download_success('B10', NC_FILE)
        self.assertEqual(None, val)

        val = ardcPickle(self.pickle_test_dir).get_latest_processed_date('B10')
        self.assertEqual(Timestamp('2022-03-01 07:38:00+0000', tz='UTC'), val)

    def test_delete_source_id(self):
        # test deletion of wrong source_id
        ardcPickle(self.pickle_test_dir).delete_source_id('DUMMY')
        val = ardcPickle(self.pickle_test_dir).get_latest_processed_date('DUMMY')
        self.assertEqual(None, val)

        # test deletion of good source_id
        ## first part to check the existing data
        val = ardcPickle(self.pickle_test_dir).get_latest_processed_date('SPOT-0278')
        self.assertEqual(Timestamp('2021-09-30 22:20:01+0000', tz='UTC'), val)
        ## second part to check the deletion
        ardcPickle(self.pickle_test_dir).delete_source_id('SPOT-0278')
        val = ardcPickle(self.pickle_test_dir).get_latest_processed_date('SPOT-0278')
        self.assertEqual(None, val)

    def test_mod_source_id_latest_downloaded_date(self):
        ardcPickle(self.pickle_test_dir).mod_source_id_latest_downloaded_date('SPOT-0278',
                                                                              Timestamp('2100-01-01 00:00:00+0000', tz='UTC'))

        val = ardcPickle(self.pickle_test_dir).get_latest_processed_date('SPOT-0278')
        self.assertEqual(Timestamp('2100-01-01 00:00:00+0000', tz='UTC'), val)


if __name__ == '__main__':
    unittest.main()
