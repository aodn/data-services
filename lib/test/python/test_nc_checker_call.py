#!/usr/bin/env python
"""
unittest for lib/python/util.py netcdf checker call function

author : besnard, laurent
"""

import os
import unittest

from util import pass_netcdf_checker


class TestPassChecker(unittest.TestCase):

    def setUp(self):
        self.nc_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'test.nc')

    def test_pass_netcdf_checker(self):
        self.assertTrue(pass_netcdf_checker(self.nc_path, ['cf:1.6']))
        self.assertTrue(pass_netcdf_checker(self.nc_path, ['imos:1.3']))

if __name__ == '__main__':
        unittest.main()
