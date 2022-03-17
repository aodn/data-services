#!/usr/bin/env python3
"""
unittest for lib/common/utils.py

author : besnard, laurent
"""

import os
import unittest
from tempfile import mkstemp

from ardc_nrt.lib.common.utils import IMOSLogging


class TestUtils(unittest.TestCase):
    def setUp(self):
        self.logfile = [mkstemp()]
        self.logging = IMOSLogging()
        self.logger = self.logging.logging_start(self.logfile[0][1])
        self.logger.info('info')
        self.logger.warning('warning')
        self.logger.error('error')

    def tearDown(self):
        self.logging.logging_stop()
        os.close(self.logfile[0][0])
        os.remove(self.logfile[0][1])

    def test_imos_logging_msg(self):
        with open(self.logfile[0][1], 'r') as f:
            for line in f:
                # the assert val is done is non conform way as the entire string
                # can be checked because of the time information added by the
                # logger
                if 'INFO - info' in line:
                    self.assertEqual(0, 0)
                elif 'WARNING - warning' in line:
                    self.assertEqual(0, 0)
                elif 'ERROR - error' in line:
                    self.assertEqual(0, 0)
                else:
                    self.assertEqual(1, 0)


if __name__ == '__main__':
    unittest.main()
