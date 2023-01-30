#!/usr/bin/env python3
"""
unittest for lib/common/utils.py

author : besnard, laurent
"""

import os
from pandas import Timestamp
import unittest
from ardc_nrt.lib.common.processing import get_timestamp_start_end_to_download


TEST_ROOT = os.path.dirname(__file__)


class TestLookup(unittest.TestCase):

    def test_get_timestamp_start_end_to_download(self):

        # case 1: source_id previously processed. new data available
        latest_timestamp_available_source_id = Timestamp('2022-03-15 12:38:00+0000', tz='UTC')
        latest_timestamp_processed_source_id = Timestamp('2022-03-10 00:00:00+0000', tz='UTC')
        timestamp_start, timestamp_end = get_timestamp_start_end_to_download(TEST_ROOT, "SPOT-0278",
                                                                             latest_timestamp_available_source_id,
                                                                             latest_timestamp_processed_source_id)

        self.assertEqual(Timestamp('2022-03-01 00:00:00+0000', tz='UTC'), timestamp_start)
        self.assertEqual(latest_timestamp_available_source_id, timestamp_end)

        # case 2: source_id never processed
        latest_timestamp_available_source_id = Timestamp('2022-03-15 12:38:00+0000', tz='UTC')
        latest_timestamp_processed_source_id = None
        timestamp_start, timestamp_end = get_timestamp_start_end_to_download(TEST_ROOT, "SPOT-0278",
                                                                             latest_timestamp_available_source_id,
                                                                             latest_timestamp_processed_source_id)

        self.assertEqual(Timestamp('2020-01-01 00:00:00+0000', tz='UTC'), timestamp_start)  # value found in sources_id_metadata.json
        self.assertEqual(latest_timestamp_available_source_id, timestamp_end)

        # case 3: source_id up to date
        latest_timestamp_available_source_id = Timestamp('2022-03-15 12:38:00+0000', tz='UTC')
        latest_timestamp_processed_source_id = Timestamp('2022-03-15 12:38:00+0000', tz='UTC')
        val = get_timestamp_start_end_to_download(TEST_ROOT, "SPOT-0278",
                                                  latest_timestamp_available_source_id,
                                                  latest_timestamp_processed_source_id)

        self.assertEqual(None, val)

        # case 4: source_id impossible latest_timestamp_processed_source_id > latest_timestamp_available_source_id
        latest_timestamp_available_source_id = Timestamp('2022-03-01 12:38:00+0000', tz='UTC')
        latest_timestamp_processed_source_id = Timestamp('2022-03-15 12:38:00+0000', tz='UTC')
        val = get_timestamp_start_end_to_download(TEST_ROOT, "SPOT-0278",
                                                  latest_timestamp_available_source_id,
                                                  latest_timestamp_processed_source_id)

        self.assertEqual(None, val)


if __name__ == '__main__':
    unittest.main()
