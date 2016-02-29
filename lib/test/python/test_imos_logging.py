#!/usr/bin/env python
"""
unittest for the logging class
lib/python/imos_logging.py library

author : besnard, laurent
"""

import os
import sys

LIB_DIR = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..'))
sys.path.insert(0, LIB_DIR)

import unittest
from tempfile import mkstemp
from python.imos_logging import IMOSLogging

class TestImosLogging(unittest.TestCase):

    def setUp(self):
        self.logfile = [mkstemp()]
        self.logging = IMOSLogging()
        self.logger  = self.logging.logging_start(self.logfile[0][1])
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
                if 'python.imos_logging - INFO - info' in line:
                    self.assertEqual(0, 0)
                elif 'python.imos_logging - WARNING - warning' in line:
                    self.assertEqual(0, 0)
                elif 'python.imos_logging - ERROR - error' in line:
                    self.assertEqual(0, 0)
                else:
                    self.assertEqual(1, 0)


if __name__ == '__main__':
        unittest.main()
