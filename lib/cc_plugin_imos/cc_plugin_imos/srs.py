#!/usr/bin/env python
'''
Compliance Test Suite for SRS IMOS NetCDF Files
http://www.imos.org.au/
'''

import numpy as np

from cc_plugin_imos import __version__
from cc_plugin_imos.imos import IMOS1_3Check, IMOS1_4Check
from cc_plugin_imos.util import (check_attribute, check_attribute_dict,
                                 is_timestamp)
from compliance_checker.base import BaseCheck, BaseNCCheck, Result


################################################################################
#
# IMOS GHRSST Checker base class
#
################################################################################

class IMOSGHRSSTCheck(BaseNCCheck):
    """Compliance-checker check suite for the IMOS SRS gridded netcdf
    """
    register_checker = True
    _cc_spec = 'ghrsst'
    _cc_spec_version = '1.0'
    _cc_checker_version = __version__
    _cc_description = "Integrated Marine Observing System (IMOS) GHRSST checker"
    _cc_url = "http://imos.org.au/"
    _cc_authors = "Laurent Besnard"

    def __init__(self):
        self.imos_1_3_check = IMOS1_3Check()
        self.imos_1_4_check = IMOS1_4Check()
        self.mandatory_global_attributes = {
            'project': ['Group for High Resolution Sea Surface Temperature'],
            'date_created': is_timestamp,
            'title': basestring
        }

        self.mandatory_variables = [
            'time',
            'lat',
            'lon',
            'dt_analysis',
            'l2p_flags',
            'quality_level',
            'satellite_zenith_angle',
            'sea_surface_temperature',
            'sses_bias',
            'sses_count',
            'sses_standard_deviation',
            'sst_dtime'
        ]

        self.time_units = ['seconds since 1981-01-01 00:00:00']

    @classmethod
    def beliefs(cls):
        """ This is the method from parent class.
        """
        return {}

    def setup(self, dataset):
        """This method is called by parent class and initialization code should
        go here
        """
        self.imos_1_3_check.setup(dataset)
        self.imos_1_4_check.setup(dataset)

    def check_global_attributes(self, dataset):
        """
        Check to ensure all global string attributes are not empty.
        """
        return self.imos_1_3_check.check_global_attributes(dataset)

    def check_variable_attributes(self, dataset):
        """
        Check to ensure all variable string attributes are not empty.
        """
        return self.imos_1_3_check.check_variable_attributes(dataset)

    def check_coordinate_variables(self, dataset):
        """
        Check all coordinate variables for
            numeric type (byte, float and integer)
            strictly monotonic values (increasing or decreasing)
        Also check that at least one of them is a spatial or temporal coordinate variable.
        """
        return self.imos_1_3_check.check_coordinate_variables(dataset)

    def check_time_variable(self, dataset):
        """
        MOD from IMOS1_3Check class to match the lower case TIME variable

        Check time variable attributes:
            standard_name
            axis
            calendar
            type
            units
        """
        time_attributes = {
            'standard_name': ['time'],
            'axis': ['T'],
            'calendar': ['gregorian']
        }

        ret_val = []

        if 'time' in dataset.variables:
            time_var = dataset.variables['time']

            result = Result(BaseCheck.MEDIUM, True, name=('var', 'time'))
            if time_var.dtype != np.int32:
                result.value = False
                result.msgs = ["The time variable should be of type int"]
            ret_val.append(result)

            ret_val.extend(
                check_attribute_dict(time_attributes, time_var)
            )

            ret_val.append(
                check_attribute('units', self.time_units, time_var, BaseCheck.MEDIUM)
            )

        return ret_val

    def check_variable_attribute_type(self, dataset):
        """
        Check variable attribute to ensure it has the same type as the variable
        """
        return self.imos_1_3_check.check_variable_attribute_type(dataset)

    def check_data_variable_present(self, dataset):
        """
        Check that there's at least one data variable exists in the file
        """
        return self.imos_1_3_check.check_data_variable_present(dataset)

    def check_data_variables(self, dataset):
        """
        Check that each data variable has the required attributes:
        - units
        - coordinates (must be a blank-separated list of valid variable names)
        """
        return self.imos_1_4_check.check_data_variables(dataset)

    def check_fill_value(self, dataset):
        """
        For every variable that has a _FillValue attribute, check that its
        value is not NaN.

        """
        return self.imos_1_4_check.check_fill_value(dataset)

    def check_mandatory_variables_exist(self, dataset):
        """
        Check that a list of variables exists defined by self.mandatory_variables
        """
        ret_val     = []
        result      = None

        for mandatory_var in self.mandatory_variables:
            result_name = ('var', mandatory_var)
            if mandatory_var in dataset.variables.keys():
                reasoning = None
            else:
                reasoning = ["Mandatory variable '%s' does not exist" % mandatory_var]

            result = Result(BaseCheck.HIGH, reasoning == None, result_name, reasoning)
            ret_val.append(result)

        return ret_val
