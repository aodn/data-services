#!/usr/bin/env python

from compliance_checker.imos import IMOSCheck
from compliance_checker.imos import util
from compliance_checker.base import DSPair
from wicken.netcdf_dogma import NetCDFDogma
from netCDF4 import Dataset
from pkg_resources import resource_filename

import unittest
import os
import re
import numpy as np


static_files = {
        'bad_data' : resource_filename('compliance_checker', 'tests/data/imos_bad_data.nc'),
        'good_data' : resource_filename('compliance_checker', 'tests/data/imos_good_data.nc'),
        'missing_data' : resource_filename('compliance_checker', 'tests/data/imos_missing_data.nc'),
        'test_variable' : resource_filename('compliance_checker', 'tests/data/imos_variable_test.nc'),
        'data_var' : resource_filename('compliance_checker', 'tests/data/imos_data_var.nc'),
        'bad_coords' : resource_filename('compliance_checker', 'tests/data/imos_bad_coords.nc'),
        }


class MockVariable(object):
    '''
    For mocking a dataset variable
    '''
    def __init__(self, name='', **argd):
        self.name = name
        for k, v in argd.iteritems():
            self.__dict__[k] = v


class TestIMOS(unittest.TestCase):
    # @see
    # http://www.saltycrane.com/blog/2012/07/how-prevent-nose-unittest-using-docstring-when-verbosity-2/
    def shortDescription(self):
        return None

    # override __str__ and __repr__ behavior to show a copy-pastable nosetest name for ion tests
    #  ion.module:TestClassName.test_function_name
    def __repr__(self):
        name = self.id()
        name = name.split('.')
        if name[0] not in ["ion", "pyon"]:
            return "%s (%s)" % (name[-1], '.'.join(name[:-1]))
        else:
            return "%s ( %s )" % (name[-1], '.'.join(name[:-2]) + ":" + '.'.join(name[-2:]))
    __str__ = __repr__

    def setUp(self):
        '''
        Initialize the dataset
        '''
        self.imos = IMOSCheck()
        self.good_dataset = self.get_pair(static_files['good_data'])
        self.bad_dataset = self.get_pair(static_files['bad_data'])
        self.missing_dataset = self.get_pair(static_files['missing_data'])
        self.test_variable_dataset = self.get_pair(static_files['test_variable'])
        self.data_variable_dataset = self.get_pair(static_files['data_var'])
        self.bad_coords_dataset = self.get_pair(static_files['bad_coords'])

    def get_pair(self, nc_dataset):
        '''
        Return a pairwise object for the dataset
        '''
        if isinstance(nc_dataset, basestring):
            nc_dataset = Dataset(nc_dataset, 'r')
            self.addCleanup(nc_dataset.close)

        dogma = NetCDFDogma('nc', self.imos.beliefs(), nc_dataset)
        pair = DSPair(nc_dataset, dogma)
        return pair

    #--------------------------------------------------------------------------------
    # Compliance Tests
    #--------------------------------------------------------------------------------

    ### Test util functions

    def _test_util_check_present_generic(self, name, ds, check_type, reasoning=None):
        result_name = ('result','name')
        weight = 1

        result = util.check_present(name, ds, check_type, result_name, weight)
        self.assertTrue(result.value)
        self.assertFalse(result.msgs)
        self.assertEqual(result.weight, weight)
        self.assertEqual(result.name, result_name)

        result = util.check_present(name, ds, check_type, result_name, weight, reasoning)
        self.assertTrue(result.value)
        self.assertFalse(result.msgs)

        if len(name) == 1:
            missing_name = ('idontexist',)
        else:
            missing_name = (name[0], 'idontexist')

        result = util.check_present(missing_name, ds, check_type, result_name, weight)
        self.assertFalse(result.value)
        self.assertTrue(result.msgs)

        result = util.check_present(missing_name, ds, check_type, result_name, weight, reasoning)
        self.assertFalse(result.value)
        self.assertEqual(result.msgs, reasoning)


    def test_util_check_present(self):
        self._test_util_check_present_generic(('project',),
                                              self.good_dataset,
                                              check_type = util.CHECK_GLOBAL_ATTRIBUTE,
                                              reasoning = ['attribute missing!'])

        self._test_util_check_present_generic(('TIME',),
                                              self.good_dataset,
                                              check_type = util.CHECK_VARIABLE,
                                              reasoning = ['variable missing!'])

        self._test_util_check_present_generic(('TIME','units'),
                                              self.good_dataset,
                                              check_type = util.CHECK_VARIABLE_ATTRIBUTE,
                                              reasoning = ['var attribute missing!'])


    def _test_util_check_value_generic(self, name, value, bad_value, operator, ds, check_type,
                                       reasoning=None, skip_check_present=True):
        result_name = ('result', 'name')
        weight = -999   # Check that return weight hasn't been hard-coded!
        result = util.check_value(name, value, operator, ds, check_type, result_name, weight,
                                  skip_check_present)
        self.assertTrue(result.value)
        self.assertFalse(result.msgs)
        self.assertEqual(result.weight, weight)
        self.assertEqual(result.name, result_name)

        result = util.check_value(name, value, operator, ds, check_type, result_name, weight, reasoning,
                                  skip_check_present)
        self.assertTrue(result.value)
        self.assertFalse(result.msgs)
        self.assertEqual(result.weight, weight)
        self.assertEqual(result.name, result_name)

        if bad_value is None: return  # skip bad value test (for email check)

        result = util.check_value(name, bad_value, operator, ds, check_type, result_name, weight,
                                  skip_check_present)
        self.assertFalse(result.value)
        self.assertTrue(result.msgs)
        self.assertEqual(result.weight, weight)
        self.assertEqual(result.name, result_name)

        result = util.check_value(name, bad_value, operator, ds, check_type, result_name, weight, reasoning,
                                  skip_check_present)
        self.assertFalse(result.value)
        self.assertEqual(result.msgs, reasoning)
        self.assertEqual(result.weight, weight)
        self.assertEqual(result.name, result_name)

    def test_util_check_value(self):
        result = util.check_value(('idontexist',), 'value', util.OPERATOR_EQUAL,
                                  self.good_dataset, util.CHECK_GLOBAL_ATTRIBUTE,
                                  ('name'), 1, skip_check_present=True)
        self.assertIsNone(result)

        self._test_util_check_value_generic(('Conventions',), 'CF-1.6,IMOS-1.3', 'bad',
                                            util.OPERATOR_EQUAL,
                                            self.good_dataset,
                                            util.CHECK_GLOBAL_ATTRIBUTE,
                                            reasoning=['global attr bad value'])

        self._test_util_check_value_generic(('TIME','valid_min'), 0., -999.,
                                            util.OPERATOR_EQUAL,
                                            self.good_dataset,
                                            util.CHECK_VARIABLE_ATTRIBUTE,
                                            reasoning=['global attr bad value'])

        geospatial_lat_min = self.good_dataset.dataset.geospatial_lat_min
        self._test_util_check_value_generic(('LATITUDE',), geospatial_lat_min, -1234.,
                                            util.OPERATOR_MIN,
                                            self.good_dataset,
                                            util.CHECK_VARIABLE,
                                            reasoning=['min value is wrong'],
                                            skip_check_present=True)

        geospatial_lat_max = self.good_dataset.dataset.geospatial_lat_max
        self._test_util_check_value_generic(('LATITUDE',), geospatial_lat_max, -1234.,
                                            util.OPERATOR_MAX,
                                            self.good_dataset,
                                            util.CHECK_VARIABLE,
                                            reasoning=['max value is wrong'],
                                            skip_check_present=True)

        self._test_util_check_value_generic(('date_created',), '%Y-%m-%dT%H:%M:%SZ', '%Y/%m/%d',
                                            util.OPERATOR_DATE_FORMAT,
                                            self.good_dataset,
                                            util.CHECK_GLOBAL_ATTRIBUTE,
                                            reasoning=['bad date format'])

        self._test_util_check_value_generic(('Conventions',), 'CF-1.6', 'bad',
                                            util.OPERATOR_SUB_STRING,
                                            self.good_dataset,
                                            util.CHECK_GLOBAL_ATTRIBUTE,
                                            reasoning=['global attr bad value'])

        self._test_util_check_value_generic(('TEMP','units'), 'Kelvin', 'metre',
                                            util.OPERATOR_CONVERTIBLE,
                                            self.good_dataset,
                                            util.CHECK_VARIABLE_ATTRIBUTE,
                                            reasoning=['bad units'])

        self._test_util_check_value_generic(('data_centre_email',), '', None,
                                            util.OPERATOR_EMAIL,
                                            self.good_dataset,
                                            util.CHECK_GLOBAL_ATTRIBUTE,
                                            reasoning=['bad email address'])
        result = util.check_value(('data_centre_email',), '',
                                  util.OPERATOR_EMAIL,
                                  self.bad_dataset,
                                  util.CHECK_GLOBAL_ATTRIBUTE,
                                  ('name'), 1, skip_check_present=True)
        self.assertFalse(result.value)
        self.assertTrue(result.msgs)

        self._test_util_check_value_generic(('quality_control_set',), [1,2,3,4], [-8,-9],
                                            util.OPERATOR_WITHIN,
                                            self.good_dataset,
                                            util.CHECK_GLOBAL_ATTRIBUTE,
                                            reasoning=['invalid value'])


    def _test_check_attribute_type_generic(self, name, expected_type, bad_type, ds, check_type, reasoning=None,
                                           skip_check_present=True):
        result_name = ('result', 'name')
        weight = -999   # Check that return weight hasn't been hard-coded!

        result = util.check_attribute_type(name, expected_type, ds, check_type, result_name, weight,
                                           skip_check_present)
        self.assertTrue(result.value)
        self.assertFalse(result.msgs)
        self.assertEqual(result.weight, weight)
        self.assertEqual(result.name, result_name)

        result = util.check_attribute_type(name, expected_type, ds, check_type, result_name, weight, reasoning,
                                           skip_check_present)
        self.assertTrue(result.value)
        self.assertFalse(result.msgs)

        result = util.check_attribute_type(name, bad_type, ds, check_type, result_name, weight,
                                           skip_check_present)
        self.assertFalse(result.value)
        self.assertTrue(result.msgs)

        result = util.check_attribute_type(name, bad_type, ds, check_type, result_name, weight, reasoning,
                                           skip_check_present)
        self.assertFalse(result.value)
        self.assertEqual(result.msgs, reasoning)


    def test_check_attribute_type(self):
        result = util.check_attribute_type(('idontexist',), basestring,
                                           self.good_dataset,
                                           util.CHECK_GLOBAL_ATTRIBUTE,
                                           ('name'), 1, skip_check_present = True)
        self.assertIsNone(result)

        self._test_check_attribute_type_generic(('title',), basestring, int,
                                                self.good_dataset,
                                                util.CHECK_GLOBAL_ATTRIBUTE,
                                                reasoning=['title not string'])

        self._test_check_attribute_type_generic(('TEMP',), np.float32, np.int,
                                                self.good_dataset,
                                                util.CHECK_VARIABLE,
                                                reasoning=['TEMP not float type'])

        self._test_check_attribute_type_generic(('TIME','valid_min'), np.float64, np.float32,
                                                self.good_dataset,
                                                util.CHECK_VARIABLE,
                                                reasoning=['TIME:valid_min bad type'])


    def test_vertical_coordinate_type(self):
        var = MockVariable('TEMP')
        self.assertIsNone(util.vertical_coordinate_type(self.good_dataset, var))
        var = MockVariable('DEPTH_quality_control')
        self.assertIsNone(util.vertical_coordinate_type(self.good_dataset, var))

        var = MockVariable('NOMINAL_DEPTH')
        self.assertEqual(util.vertical_coordinate_type(self.good_dataset, var), 'depth')
        var = MockVariable('HEIGHT_ABOVE_SENSOR')
        self.assertEqual(util.vertical_coordinate_type(self.good_dataset, var), 'height')

        var = MockVariable('NONAME', standard_name='time')
        self.assertIsNone(util.vertical_coordinate_type(self.good_dataset, var))
        var = MockVariable('NONAME', standard_name='height')
        self.assertEqual(util.vertical_coordinate_type(self.good_dataset, var), 'height')

        var = MockVariable('NONAME', positive='negative')
        self.assertIsNone(util.vertical_coordinate_type(self.good_dataset, var))
        var = MockVariable('NONAME', positive='down')
        self.assertEqual(util.vertical_coordinate_type(self.good_dataset, var), 'depth')

        var = MockVariable('NONAME', axis='X')
        self.assertIsNone(util.vertical_coordinate_type(self.good_dataset, var))
        var = MockVariable('NONAME', axis='Z')
        self.assertEqual(util.vertical_coordinate_type(self.good_dataset, var), 'unknown')



    ### Test compliance checks

    def test_check_global_attributes(self):
        ret_val = self.imos.check_global_attributes(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_global_attributes(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

    def test_check_variable_attributes(self):

        ret_val = self.imos.check_variable_attributes(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_variable_attributes(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_project_attribute(self):
        ret_val = self.imos.check_project_attribute(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_project_attribute(self.bad_dataset)
        
        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_naming_authority(self):
        ret_val = self.imos.check_naming_authority(self.good_dataset)
        
        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_naming_authority(self.bad_dataset)
        
        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_data_centre(self):
        ret_val = self.imos.check_data_centre(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_data_centre(self.bad_dataset)
        
        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_author(self):
        ret_val = self.imos.check_author(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_author(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_geospatial_lat_min_max(self):
        ret_val = self.imos.check_geospatial_lat_min_max(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_geospatial_lat_min_max(self.bad_dataset)

        for result in ret_val:
            if 'check_attribute_type' in result.name:
                self.assertTrue(result.value)
            else:
                self.assertFalse(result.value)

        ret_val = self.imos.check_geospatial_lat_min_max(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_geospatial_lon_min_max(self):
        ret_val = self.imos.check_geospatial_lat_min_max(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_geospatial_lat_min_max(self.bad_dataset)

        for result in ret_val:
            if 'check_attribute_type' in result.name:
                self.assertTrue(result.value)
            else:
                self.assertFalse(result.value)

        ret_val = self.imos.check_geospatial_lat_min_max(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_geospatial_vertical_min_max(self):
        ret_val = self.imos.check_geospatial_vertical_min_max(self.good_dataset)
        self.assertEqual(len(ret_val), 4)
        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_geospatial_vertical_min_max(self.bad_dataset)
        self.assertEqual(len(ret_val), 1)
        self.assertFalse(ret_val[0].value)
        self.assertIn('variable_present', ret_val[0].name)

        ret_val = self.imos.check_geospatial_vertical_min_max(self.bad_coords_dataset)
        self.assertEqual(len(ret_val), 4)
        for result in ret_val:
            if result.name[2] == 'type':
                self.assertTrue(result.value)
            else:
                self.assertFalse(result.value)

        ret_val = self.imos.check_geospatial_vertical_min_max(self.missing_dataset)
        self.assertEqual(len(ret_val), 0)

    def test_check_time_coverage(self):
        ret_val = self.imos.check_time_coverage(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_time_coverage(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_time_coverage(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_title(self):
        ret_val = self.imos.check_title(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_title(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_title(self.missing_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_date_created(self):
        ret_val = self.imos.check_date_created(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_date_created(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_abstract(self):

        ret_val = self.imos.check_abstract(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_abstract(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_abstract(self.missing_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_data_centre_email(self):
        ret_val = self.imos.check_data_centre_email(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_data_centre_email(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_data_centre_email(self.missing_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_principal_investigator(self):
        ret_val = self.imos.check_principal_investigator(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_principal_investigator(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_principal_investigator(self.missing_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_citation(self):
        ret_val = self.imos.check_citation(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_citation(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_citation(self.missing_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_acknowledgement(self):
        ret_val = self.imos.check_acknowledgement(self.good_dataset)
        self.assertTrue(ret_val[0].value)
        self.assertTrue(ret_val[1].value)

        ret_val = self.imos.check_acknowledgement(self.bad_dataset)
        self.assertTrue(ret_val[0].value)
        self.assertFalse(ret_val[1].value)

    def test_check_variables_long_name(self):
        ret_val = self.imos.check_variables_long_name(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_variables_long_name(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_variables_long_name(self.missing_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_check_coordinate_variables(self):
        self.imos.setup(self.good_dataset)
        self.assertEqual(len(self.imos._coordinate_variables), 1)
        ret_val = self.imos.check_coordinate_variables(self.good_dataset)
        for result in ret_val:
            self.assertTrue(result.value)

        self.imos.setup(self.bad_dataset)
        self.assertEqual(len(self.imos._coordinate_variables), 2)
        ret_val = self.imos.check_coordinate_variables(self.bad_dataset)
        self.assertEqual(len(ret_val), 5)
        for result in ret_val:
            if 'check_variable_type' in result.name:
                self.assertTrue(result.value)
            else:
                self.assertFalse(result.value)


    def test_check_time_variable(self):
        ret_val = self.imos.check_time_variable(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_time_variable(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_time_variable(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_longitude_variable(self):
        ret_val = self.imos.check_longitude_variable(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_longitude_variable(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_longitude_variable(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_latitude_variable(self):
        ret_val = self.imos.check_latitude_variable(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_latitude_variable(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_latitude_variable(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_vertical_variable(self):
        ret_val = self.imos.check_vertical_variable(self.good_dataset)
        self.assertGreater(len(ret_val), 0)
        for result in ret_val:
            self.assertIn(result.name[1], ('DEPTH', 'NOMINAL_DEPTH'))
            self.assertTrue(result.value)

        ret_val = self.imos.check_vertical_variable(self.bad_coords_dataset)
        self.assertEqual(len(ret_val), 23)
        for result in ret_val:
            var, attr = result.name[1:3]
            self.assertIn(var, ('DEPTH', 'VERTICAL', 'HHH'))
            if (var, attr) in (('VERTICAL', 'positive'),
                               ('VERTICAL', 'variable_type'),
                               ('HHH', 'axis'),
                               ('HHH', 'variable_type')):
                self.assertTrue(result.value)
            else:
                self.assertFalse(result.value)

        ret_val = self.imos.check_vertical_variable(self.missing_dataset)
        self.assertEqual(len(ret_val), 0)

    def test_check_variable_attribute_type(self):
        ret_val = self.imos.check_variable_attribute_type(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_variable_attribute_type(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

    def test_data_variable_list(self):
        self.imos.setup(self.data_variable_dataset)
        self.assertEqual(len(self.imos._data_variables), 2)
        self.assertEqual(self.imos._data_variables[0].name, 'data_variable')
        self.assertEqual(self.imos._data_variables[1].name, 'random_data')

    def test_check_data_variables(self):
        self.imos.setup(self.good_dataset)
        ret_val = self.imos.check_data_variables(self.good_dataset)
        self.assertEqual(len(ret_val), 5)
        for result in ret_val:
            self.assertTrue(result.value)

        self.imos.setup(self.data_variable_dataset)
        ret_val = self.imos.check_data_variables(self.data_variable_dataset)
        self.assertEqual(len(ret_val), 5)
        self.assertTrue(ret_val[0].value)
        for i in range(1,5):
            self.assertFalse(ret_val[i].value)

    def test_check_quality_control_variable_matches_variable(self):
        self.imos.setup(self.test_variable_dataset)
        ret_val = self.imos.check_quality_control_variable_matches_variable(self.test_variable_dataset)
        self.assertIsNotNone(ret_val)
        self.assertEqual(len(ret_val), 10)

        self.assertTrue(ret_val[0].value)
        self.assertTrue(ret_val[1].value)
        self.assertTrue(ret_val[6].value)
        self.assertFalse(ret_val[7].value)
        self.assertFalse(ret_val[8].value)

    def test_check_quality_control_variable_dimensions(self):
        self.imos.setup(self.test_variable_dataset)
        ret_val = self.imos.check_quality_control_variable_dimensions(self.test_variable_dataset)

        self.assertIsNotNone(ret_val)
        self.assertEqual(len(ret_val), 2)

        self.assertTrue(ret_val[0].value)
        self.assertFalse(ret_val[1].value)

    def test_check_quality_control_variable_listed(self):
        self.imos.setup(self.test_variable_dataset)
        ret_val = self.imos.check_quality_control_variable_listed(self.test_variable_dataset)

        self.assertIsNotNone(ret_val)
        self.assertEqual(len(ret_val), 6)

        self.assertTrue(ret_val[0].value)
        self.assertTrue(ret_val[1].value)
        
    def test_check_quality_control_conventions_for_quality_control_variable(self):
        self.imos.setup(self.test_variable_dataset)
        ret_val = self.imos.check_quality_control_conventions_for_quality_control_variable(self.test_variable_dataset)
        self.assertEqual(len(ret_val), 6)
        for result in ret_val:
            if result.name[1:] == ('LONGITUDE_quality_control', 'quality_control_conventions') or \
               result.name[1] == 'LATITUDE_quality_control' or \
               result.name[1] == 'bad1_quality_control' or \
               result.name[1] == 'bad2_qc' or \
               result.name[1] == 'bad3_qc':
                self.assertFalse(result.value)
            else:
                self.assertTrue(result.value)

    def test_check_quality_control_variable_standard_name(self):
        self.imos.setup(self.test_variable_dataset)

        ret_val = self.imos.check_quality_control_variable_standard_name(self.test_variable_dataset)

        self.assertIsNotNone(ret_val)
        self.assertEqual(len(ret_val), 4)

        self.assertTrue(ret_val[0].value)
        self.assertTrue(ret_val[1].value)
        self.assertFalse(ret_val[2].value)
        self.assertTrue(ret_val[3].value)

    def test_check_geospatial_lat_units(self):
        ret_val = self.imos.check_geospatial_lat_units(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_geospatial_lat_units(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_geospatial_lat_units(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_geospatial_lon_units(self):
        ret_val = self.imos.check_geospatial_lon_units(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_geospatial_lon_units(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_geospatial_lon_units(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_geospatial_vertical_positive(self):
        ret_val = self.imos.check_geospatial_vertical_positive(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_geospatial_vertical_positive(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_geospatial_vertical_positive(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_author_email(self):
        ret_val = self.imos.check_author_email(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_author_email(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_author_email(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_principal_investigator_email(self):
        ret_val = self.imos.check_principal_investigator_email(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_principal_investigator_email(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_principal_investigator_email(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_quality_control_set(self):
        ret_val = self.imos.check_quality_control_set(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_quality_control_set(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_quality_control_set(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_local_time_zone(self):
        ret_val = self.imos.check_local_time_zone(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_local_time_zone(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_local_time_zone(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)

    def test_check_geospatial_vertical_units(self):
        ret_val = self.imos.check_geospatial_vertical_units(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_geospatial_vertical_units(self.bad_dataset)

        for result in ret_val:
            self.assertFalse(result.value)

        ret_val = self.imos.check_geospatial_vertical_units(self.missing_dataset)

        self.assertEqual(len(ret_val), 0)
        
    def test_check_conventions_attribute(self):
        ret_val = self.imos.check_conventions(self.good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.imos.check_conventions(self.bad_dataset)
        
        for result in ret_val:
            self.assertFalse(result.value)
