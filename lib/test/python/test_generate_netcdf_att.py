#!/usr/bin/env python
"""
unittest on the generation of gatts and var atts on a netcdf file using the
lib/python/generate_netcdf_att.py library

author : besnard, laurent
"""

import os
import sys

LIB_DIR = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..'))
sys.path.insert(0, LIB_DIR)

import unittest
import textwrap
from netCDF4 import Dataset
from tempfile import mkstemp
from python.generate_netcdf_att import *

class TestGenerateNetCDFAtt(unittest.TestCase):

    def setUp(self):
        self.setup_netcdf_file()
        self.setup_conf_file_att()

    def setup_netcdf_file(self):
        self.tmp_nc_id, self.netcdf_file_path = mkstemp(suffix='.nc')
        self.ncid = Dataset(self.netcdf_file_path, "w", format="NETCDF4")

        # set up dimensions
        self.ncid.createDimension("TIME", 10)

        # set up variables
        var_time = self.ncid.createVariable("TIME", "d", "TIME", fill_value=
                                       get_imos_parameter_info('TIME',
                                                               '_FillValue'))
        var_lat  = self.ncid.createVariable("LATITUDE", "d", "TIME",
                                            fill_value=
                                            get_imos_parameter_info('LATITUDE',
                                                               '_FillValue'))
        var_lon  = self.ncid.createVariable("LONGITUDE", "d", "TIME", fill_value=
                                       get_imos_parameter_info('LONGITUDE',
                                                               '_FillValue'))
        var_temp = self.ncid.createVariable("TEMP", "f8", "TIME", fill_value=
                                       get_imos_parameter_info('TEMP', '_FillValue'))

    def setup_conf_file_att(self):
        config = textwrap.dedent(
            """
            [global_attributes]
            history      = created
            date_created = 1970-01-01T00:00:00Z
            author       = name
            author_email = you@domain.org
            Conventions  = CF-1.6

            [TIME]
            calendar = gregorian
            axis     = T

            [LONGITUDE]
            comment = test
            axis    = X

            [LATITUDE]
            axis = Y

            [TEMP]
            coordinates = TIME LATITUDE LONGITUDE
            """
        )
        self.tmp_conf_id, self.conf_file = mkstemp()
        with open(self.conf_file, 'w') as f:
            f.write(config)

    def tearDown(self):
        self.ncid.close()
        os.close(self.tmp_nc_id)
        os.close(self.tmp_conf_id)
        os.remove(self.conf_file)
        os.remove(self.netcdf_file_path)

    def test_generate_netcdf_att(self):
        generate_netcdf_att(self.ncid, self.conf_file)

        self.assertEqual(self.ncid.date_created, '1970-01-01T00:00:00Z')
        self.assertEqual(self.ncid.variables['TEMP'].long_name,
                         'sea_water_temperature')

if __name__ == '__main__':
        unittest.main()
