#!/usr/bin/env python

import os
import shutil
import unittest

import netCDF4
from netCDF4 import Dataset

from cc_plugin_imos.srs import IMOSGHRSSTCheck
from cc_plugin_imos.tests.resources import static_files_testing


################################################################################
#
# SRS GHRSST Checker
#
################################################################################

class TestGHRSSTIMOSBase(unittest.TestCase):
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

    def load_dataset(self, nc_dataset):
        '''
        Return a loaded NC Dataset for the given path
        '''
        if not isinstance(nc_dataset, str):
            raise ValueError("nc_dataset should be a string")

        nc_dataset = Dataset(nc_dataset, 'r')
        self.addCleanup(nc_dataset.close)
        return nc_dataset

    @classmethod
    def setUpClass(cls):
        cls.static_files = static_files_testing()

    @classmethod
    def tearDownClass(cls):
        for file_path in cls.static_files.values():
            shutil.rmtree(os.path.dirname(file_path))

    def setUp(self):
        '''
        Initialize the dataset
        '''
        self.srs              = IMOSGHRSSTCheck()
        self.srs_good_dataset = self.load_dataset(self.static_files['ghrsst_good_data'])
        self.srs_bad_dataset  = self.load_dataset(self.static_files['ghrsst_bad_data'])

    def test_check_global_attributes(self):
        ret_val = self.srs.check_global_attributes(self.srs_bad_dataset)

        for result in ret_val:
            if result.name[1] in ('title'):
                self.assertFalse(result.value)

        ret_val = self.srs.check_global_attributes(self.srs_good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

    def test_check_variable_attributes(self):
        ret_val = self.srs.check_variable_attributes(self.srs_good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.srs.check_variable_attributes(self.srs_bad_dataset)

        # test if at least one variable attribute is empty
        glob_result = True
        for result in ret_val:
            if result.value is False:
                glob_result = False

        self.assertFalse(glob_result)

    def test_check_coordinate_variables(self):
        self.srs.setup(self.srs_good_dataset)
        self.assertEqual(len(self.srs.imos_1_3_check._coordinate_variables), 3)
        ret_val = self.srs.check_coordinate_variables(self.srs_good_dataset)
        for result in ret_val:
            self.assertTrue(result.value)

        self.srs.setup(self.srs_bad_dataset)
        self.assertEqual(len(self.srs.imos_1_3_check._coordinate_variables), 4)

    def test_check_time_variable(self):
        ret_val = self.srs.check_time_variable(self.srs_good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.srs.check_time_variable(self.srs_bad_dataset)

        for result in ret_val[1:]:
            self.assertFalse(result.value)

        self.assertEqual(len(ret_val), 5)

    def test_check_variable_attribute_type(self):
        ret_val = self.srs.check_variable_attribute_type(self.srs_good_dataset)

        for result in ret_val:
            self.assertTrue(result.value)

        ret_val = self.srs.check_variable_attribute_type(self.srs_bad_dataset)

        for result in ret_val:
            if result.value is False:  # check l2p_flags:valid_min
                self.assertFalse(result.value)

    def test_check_data_variable_present(self):
        self.srs.setup(self.srs_good_dataset)
        ret_val = self.srs.check_data_variable_present(self.srs_good_dataset)
        self.assertEqual(len(ret_val), 1)
        self.assertTrue(ret_val[0].value)

    def test_check_data_variables(self):
        self.srs.setup(self.srs_good_dataset)
        ret_val    = self.srs.check_data_variables(self.srs_good_dataset)
        passed_var = [r.name[1] for r in ret_val if r.value]
        self.assertEqual(len(ret_val), 24)
        self.assertEqual(len(passed_var), 24)

        self.srs.setup(self.srs_bad_dataset)
        ret_val    = self.srs.check_data_variables(self.srs_bad_dataset)
        failed_var = [r.name[1] for r in ret_val if not r.value]
        self.assertEqual(len(ret_val), 26)
        self.assertEqual(len(failed_var), 2)
        self.assertEqual(set(failed_var), set(['random_var']))

    @unittest.skipUnless(netCDF4.__netcdf4libversion__ >= '4.3',
                         'requires netCDF4 library version >= 4.3')
    def test_check_fill_value(self):
        ret_val = self.srs.check_fill_value(self.srs_bad_dataset)
        failed_var = [r.name[1] for r in ret_val if not r.value]
        self.assertEqual(failed_var, ['lon'])

    def test_check_mandatory_variables_exist(self):
        self.srs.setup(self.srs_good_dataset)
        ret_val = self.srs.check_mandatory_variables_exist(self.srs_good_dataset)
        self.assertEqual(len(ret_val), len(self.srs.mandatory_variables))

        self.srs.setup(self.srs_bad_dataset)
        self.srs.mandatory_variables = ['mandatory_variable', 'random_var']
        ret_val = self.srs.check_mandatory_variables_exist(self.srs_bad_dataset)
        self.assertFalse(ret_val[0].value)
        self.assertTrue(ret_val[1].value)


if __name__ == '__main__':
    unittest.main()
