#!/usr/bin/env python
'''
Compliance Test Suite for the Integrated Marine Observing System
http://www.imos.org.au/
'''

import numpy as np
import re
from datetime import datetime
from cf_units import date2num

from compliance_checker.cf.util import find_coord_vars, _possibleaxis, _possibleaxisunits
from compliance_checker.base import BaseCheck, BaseNCCheck, Result

from cc_plugin_imos.util import is_monotonic
from cc_plugin_imos.util import is_numeric, numeric_types
from cc_plugin_imos.util import is_timestamp
from cc_plugin_imos.util import is_valid_email
from cc_plugin_imos.util import find_ancillary_variables
from cc_plugin_imos.util import find_data_variables
from cc_plugin_imos.util import find_quality_control_variables
from cc_plugin_imos.util import find_ancillary_variables_by_variable
from cc_plugin_imos.util import check_present
from cc_plugin_imos.util import check_value
from cc_plugin_imos.util import check_attribute_type
from cc_plugin_imos.util import vertical_coordinate_type
from cc_plugin_imos.util import check_attribute, check_attribute_dict
from cc_plugin_imos import __version__


################################################################################
#
# IMOS Checker base class
#
################################################################################

class IMOSBaseCheck(BaseNCCheck):
    """Compliance-checker check suite for the IMOS netcdf conventions
    """
    register_checker = False
    _cc_spec = 'imos'
    _cc_spec_version = 'base'
    _cc_checker_version = __version__
    _cc_description = "Integrated Marine Observing System (IMOS) NetCDF Conventions"
    _cc_url = "http://imos.org.au/"
    _cc_authors =  "Xiao Ming Fu, Marty Hidas"


    CHECK_VARIABLE = 1
    CHECK_GLOBAL_ATTRIBUTE = 0
    CHECK_VARIABLE_ATTRIBUTE = 3

    OPERATOR_EQUAL = 1
    OPERATOR_MIN = 2
    OPERATOR_MAX = 3
    OPERATOR_WITHIN = 4
    OPERATOR_DATE_FORMAT = 5
    OPERATOR_SUB_STRING = 6
    OPERATOR_CONVERTIBLE = 7
    OPERATOR_EMAIL = 8


    def __init__(self):
        self.mandatory_global_attributes = {
            'Conventions': '(.*,)?CF-1.6,IMOS-%s(,.*)?' % self._cc_spec_version,
            'project': ['Integrated Marine Observing System (IMOS)'],
            'naming_authority': ['IMOS'],
            'date_created': is_timestamp,
            'title': basestring,
            'abstract': basestring,
            'author': basestring,
            'principal_investigator': basestring,
            'citation': basestring,
        }

        self.optional_global_attributes = {
            'geospatial_lat_units': ['degrees_north'],
            'geospatial_lon_units': ['degrees_east'],
            'geospatial_vertical_positive': ['up', 'down'],
            'local_time_zone': [i*0.5 for i in range(-24, 24)],
            'author_email': is_valid_email,
            'principal_investigator_email': is_valid_email,
        }

        self.time_units = ['days since 1950-01-01 00:00:00 UTC']

        self.quality_control_conventions = [
            "IMOS standard set using the IODE flags",
            "ARGO quality control procedure",
            "BOM (SST and Air-Sea flux) quality control procedure",
            "WOCE quality control procedure"
        ]

    @classmethod
    def beliefs(cls):
        """ This is the method from parent class.
        """
        return {}

    def setup(self, dataset):
        """This method is called by parent class and initialization code should
        go here
        """
        self._coordinate_variables = find_coord_vars(dataset)
        self._ancillary_variables = find_ancillary_variables(dataset)

        self._data_variables = find_data_variables(dataset,\
                                self._coordinate_variables,\
                                self._ancillary_variables)

        self._quality_control_variables = find_quality_control_variables(dataset)

    def _check_str_type(self, dataset, name):
        """
        Check the global attribute has string type

        params:
            name (str): attribute name
        return:
            result (list): a list of Result objects
        """
        ret_val = []
        result_name = ('globalattr', name, 'check_atttribute_type')
        reasoning = ["Attribute type is not string"]
        result = check_attribute_type((name,),
                                      basestring,
                                      dataset,
                                      self.CHECK_GLOBAL_ATTRIBUTE,
                                      result_name,
                                      BaseCheck.HIGH,
                                      reasoning,
                                      False)
        ret_val.append(result)
        return ret_val

    def check_mandatory_global_attributes(self, dataset):
        """
        Check for presence and content of mandatory global attributes.
        """
        return check_attribute_dict(self.mandatory_global_attributes, dataset)

    def check_optional_global_attributes(self, dataset):
        """
        Check for presence and content of optional global attributes.
        """
        return check_attribute_dict(self.optional_global_attributes,
                                    dataset,
                                    BaseCheck.MEDIUM,
                                    optional=True)

    def check_global_attributes(self, dataset):
        """
        Check to ensure all global string attributes are not empty.
        """
        ret_val = []
        result = None

        for name in dataset.ncattrs():
            attribute_value = getattr(dataset, name)
            if isinstance(attribute_value, basestring):
                result_name = ('globalattr', name,'check_attribute_empty')
                reasoning = None
                if not attribute_value:
                    #empty global attribute
                    reasoning = ["Attribute value is empty"]

                result = Result(BaseCheck.HIGH, reasoning == None, result_name, reasoning)
                ret_val.append(result)

        return ret_val

    def check_variable_attributes(self, dataset):
        """
        Check to ensure all variable string attributes are not empty.
        """
        ret_val = []
        result = None

        for variable_name, variable in dataset.variables.iteritems():
            for attribute_name in variable.ncattrs():
                attribute_value = getattr(variable, attribute_name)

                if isinstance(attribute_value, basestring):
                    result_name = ('var', variable_name, attribute_name,'check_attribute_empty')
                    reasoning = None
                    if not attribute_value:
                        #empty variable attribute
                        reasoning = ["Attribute value is empty"]

                    result = Result(BaseCheck.HIGH, reasoning == None, result_name, reasoning)
                    ret_val.append(result)

        return ret_val

    def check_geospatial_lat_min_max(self, dataset):
        """
        Check the global geospatial_lat_min and geospatial_lat_max attributes
        match range in data and numeric type
        """
        ret_val = []

        result_name = ('globalattr', 'geospatial_lat_min', 'check_attribute_type')
        result = check_present(('LATITUDE',), dataset, self.CHECK_VARIABLE,
                                result_name,
                                BaseCheck.HIGH)

        if result.value:
            result_name = ('globalattr', 'geospatial_lat_min', 'check_attribute_type')
            result = check_attribute_type(('geospatial_lat_min',),
                                        numeric_types,
                                        dataset,
                                        self.CHECK_GLOBAL_ATTRIBUTE,
                                        result_name,
                                        BaseCheck.HIGH,
                                        ["Attribute type is not numeric"])

            if result:
                ret_val.append(result)

            if result.value:
                geospatial_lat_min = getattr(dataset, "geospatial_lat_min", None)
                result_name = ('globalattr', 'geospatial_lat_min','check_minimum_value')
                result = check_value(('LATITUDE',),
                                        geospatial_lat_min,
                                        self.OPERATOR_MIN,
                                        dataset,
                                        self.CHECK_VARIABLE,
                                        result_name,
                                        BaseCheck.HIGH)
                ret_val.append(result)

            result_name = ('globalattr', 'geospatial_lat_max', 'check_attribute_type')
            result2 = check_attribute_type(('geospatial_lat_max',),
                                            numeric_types,
                                            dataset,
                                            self.CHECK_GLOBAL_ATTRIBUTE,
                                            result_name,
                                            BaseCheck.HIGH,
                                            ["Attribute type is not numeric"])
            if result2:
                ret_val.append(result2)

            if result2.value:
                geospatial_lat_max = getattr(dataset, "geospatial_lat_max", None)
                result_name = ('globalattr', 'geospatial_lat_max','check_maximum_value')
                result = check_value(('LATITUDE',),
                                        geospatial_lat_max,
                                        self.OPERATOR_MAX,
                                        dataset,
                                        self.CHECK_VARIABLE,
                                        result_name,
                                        BaseCheck.HIGH)
                ret_val.append(result)

        return ret_val

    def check_geospatial_lon_min_max(self, dataset):
        """
        Check the global geospatial_lon_min and geospatial_lon_max attributes
        match range in data and numeric type
        """
        ret_val = []

        result_name = ('globalattr', 'geospatial_lon_min', 'check_attribute_type')
        result = check_present(('LONGITUDE',), dataset, self.CHECK_VARIABLE,
                                result_name,
                                BaseCheck.HIGH)

        if result.value:
            result_name = ('globalattr', 'geospatial_lon_min', 'check_attribute_type')
            result = check_attribute_type(('geospatial_lon_min',),
                                            numeric_types,
                                            dataset,
                                            self.CHECK_GLOBAL_ATTRIBUTE,
                                            result_name,
                                            BaseCheck.HIGH,
                                            ["Attribute type is not numeric"])

            if result:
                ret_val.append(result)

            if result.value:
                geospatial_lon_min = getattr(dataset, "geospatial_lon_min", None)
                result_name = ('globalattr', 'geospatial_lon_min','check_minimum_value')
                result = check_value(('LONGITUDE',),
                                       geospatial_lon_min,
                                       self.OPERATOR_MIN,
                                       dataset,
                                       self.CHECK_VARIABLE,
                                       result_name,
                                       BaseCheck.HIGH)
                ret_val.append(result)

            result_name = ('globalattr', 'geospatial_lon_max', 'check_attribute_type')
            result2 = check_attribute_type(('geospatial_lon_max',),
                                            numeric_types,
                                            dataset,
                                            self.CHECK_GLOBAL_ATTRIBUTE,
                                            result_name,
                                            BaseCheck.HIGH,
                                            ["Attribute type is not numeric"])
            if result2:
                ret_val.append(result2)

            if result2.value:
                geospatial_lon_max = getattr(dataset, "geospatial_lon_max", None)
                result_name = ('globalattr', 'geospatial_lon_max','check_maximum_value')
                result = check_value(('LONGITUDE',),
                                       geospatial_lon_max,
                                       self.OPERATOR_MAX,
                                       dataset,
                                       self.CHECK_VARIABLE,
                                       result_name,
                                       BaseCheck.HIGH)
                ret_val.append(result)

        return ret_val

    def check_geospatial_vertical_min_max(self, dataset):
        """
        Check the global geospatial_vertical_min and
        geospatial_vertical_max attributes match range in data and numeric type.
        Only applies to discrete sampling geometry (DSG) files, i.e. those with
        a featureType attribute.
        """

        # identify vertical vars
        vert_vars = [v for v in dataset.variables.itervalues() \
                             if vertical_coordinate_type(dataset, v) is not None]

        vert_min = getattr(dataset, 'geospatial_vertical_min', None)
        vert_max = getattr(dataset, 'geospatial_vertical_max', None)

        # Skip if not a DSG file
        if not hasattr(dataset, 'featureType'):
            return []

        # Do we have any vertical variables to compare with?
        if not vert_vars:
            if not (vert_min and vert_max):
                # no vertical information at all, nothing to report
                return []

            reasoning = ['Could not find vertical variable to check values of ' \
                         'geospatial_vertical_min/max']
            result = Result(BaseCheck.MEDIUM,
                            False,
                            ('globalattr','geospatial_vertical_extent','variable_present'),
                            reasoning)
            return [result]

        # Check attribute presence and types
        ret_val = []
        bad_attr = False
        for attr in ['geospatial_vertical_min', 'geospatial_vertical_max']:
            result_name = ('globalattr', attr, 'type')
            result = check_attribute_type((attr,),
                                          numeric_types,
                                          dataset,
                                          self.CHECK_GLOBAL_ATTRIBUTE,
                                          result_name,
                                          BaseCheck.HIGH,
                                          ["Attribute %s should have numeric type" % attr])
            ret_val.append(result)
            if not result.value:
                bad_attr = True

        # attributes missing or have non-numeric types, checks below
        # will just cause errors, so skip them
        if bad_attr:
            return ret_val

        obs_mins = {var.name:np.nanmin(var.__array__()) for var in vert_vars if not np.isnan(var.__array__()).all()}
        obs_maxs = {var.name:np.nanmax(var.__array__()) for var in vert_vars if not np.isnan(var.__array__()).all()}

        min_pass = any((np.isclose(vert_min, min_val) for min_val in obs_mins.itervalues()))
        max_pass = any((np.isclose(vert_max, max_val) for max_val in obs_maxs.itervalues()))

        reasoning = []
        if not min_pass:
            reasoning = ["geospatial_vertical_min value (%s) did not match minimum value " \
                         "of any vertical variable %s" % (vert_min, obs_mins)]
        result_name = ('globalattr','geospatial_vertical_min','match_data')
        ret_val.append(Result(BaseCheck.HIGH, min_pass, result_name, reasoning))

        reasoning = []
        if not max_pass:
            reasoning = ["geospatial_vertical_max value (%s) did not match maximum value " \
                         "of any vertical variable %s" % (vert_max, obs_maxs)]
        result_name = ('globalattr','geospatial_vertical_max','match_data')
        ret_val.append(Result(BaseCheck.HIGH, max_pass, result_name, reasoning))

        return ret_val

    def check_time_coverage(self, dataset):
        """
        Check the global attributes time_coverage_start/time_coverage_end
        approximately match range in data and format 'YYYY-MM-DDThh:mm:ssZ'
        """
        ret_val = []
        result_name = ('globalattr', 'time_coverage_start','check_date_format')

        result = check_present(('TIME',), dataset, self.CHECK_VARIABLE,
                                result_name,
                                BaseCheck.HIGH)

        if result.value:
            date_attribute_format = '%Y-%m-%dT%H:%M:%SZ'

            time_var = dataset.variables.get('TIME', None)
            time_min = np.amin(time_var.__array__())
            time_max = np.amax(time_var.__array__())

            time_units = getattr(time_var, "units", None)
            time_calendar = getattr(time_var, "calendar", "gregorian")

            results = self._check_str_type(dataset, 'time_coverage_start')
            result = results[0]
            if result.value:
                result_name = ('globalattr', 'time_coverage_start','check_date_format')
                result = check_value(('time_coverage_start',),
                                    date_attribute_format,
                                    self.OPERATOR_DATE_FORMAT,
                                    dataset,
                                    self.CHECK_GLOBAL_ATTRIBUTE,
                                    result_name,
                                    BaseCheck.HIGH)
            if result: 
                ret_val.append(result)

            if result.value:
                time_coverage_start_string = getattr(dataset, "time_coverage_start", None)
                time_coverage_start_datetime = datetime.strptime(time_coverage_start_string, date_attribute_format)
                time_coverage_start = date2num(time_coverage_start_datetime, time_units, time_calendar)
                result_name = ('globalattr', 'time_coverage_start','match_min_TIME')
                reasoning = None
                min_pass = np.isclose(time_min, time_coverage_start)
                if not min_pass:
                    reasoning = ["Attribute time_coverage_start value doesn't match the minimum TIME value"]

                result = Result(BaseCheck.HIGH, min_pass, result_name, reasoning)
                ret_val.append(result)

            results = self._check_str_type(dataset, 'time_coverage_end')
            result = results[0]
            if result.value:
                result_name = ('globalattr', 'time_coverage_end','check_date_format')
                result = check_value(('time_coverage_end',),
                                    date_attribute_format,
                                    self.OPERATOR_DATE_FORMAT,
                                    dataset,
                                    self.CHECK_GLOBAL_ATTRIBUTE,
                                    result_name,
                                    BaseCheck.HIGH)
            if result:
                ret_val.append(result)

            if result.value:
                time_coverage_end_string = getattr(dataset, "time_coverage_end", None)
                time_coverage_end_datetime = datetime.strptime(time_coverage_end_string, date_attribute_format)
                time_coverage_end = date2num(time_coverage_end_datetime, time_units, time_calendar)
                result_name = ('globalattr', 'time_coverage_end','match_max_TIME')
                reasoning = None
                max_pass = np.isclose(time_max, time_coverage_end)
                if not max_pass:
                    reasoning = ["Attribute time_coverage_end value doesn't match the maximum TIME value"]

                result = Result(BaseCheck.HIGH, max_pass, result_name, reasoning)
                ret_val.append(result)

        return ret_val

    def check_acknowledgement(self, dataset):
        """
        Check the global acknowledgement attribute and ensure it contains the
        required text.
        """
        ret_val = []
        old_pattern = ".*Any users of IMOS data are required to clearly" \
                      " acknowledge the source of the material in the format:" \
                      ".*" \
                      "Data was sourced from the Integrated Marine Observing" \
                      " System \(IMOS\) - IMOS is supported by the Australian" \
                      " Government through the National Collaborative Research" \
                      " Infrastructure Strategy \(NCRIS\) and the Super" \
                      " Science Initiative \(SSI\)"
        new_pattern = ".*Any users of IMOS data are required to clearly" \
                      " acknowledge the source of the material derived from" \
                      " IMOS in the format:" \
                      ".*" \
                      "Data was sourced from the Integrated Marine Observing" \
                      " System \(IMOS\) - IMOS is a national collaborative" \
                      " research infrastructure," \
                      " supported by the Australian Government"

        acknowledgement = getattr(dataset, 'acknowledgement', None)

        # check the attribute is present
        present = True
        reasoning = None
        if acknowledgement is None:
            present = False
            reasoning = ['Missing global attribute acknowledgement']
        result_name = ('globalattr', 'acknowledgement', 'present')
        result = Result(BaseCheck.HIGH, present, result_name, reasoning)

        ret_val.append(result)

        # skip the rest if attribute not there
        if not result.value:
            return ret_val

        # test whether old or new substrings match the attribute value
        passed = False
        reasoning = ["acknowledgement string doesn't contain the required text"]
        if re.match(old_pattern, acknowledgement) or \
           re.match(new_pattern, acknowledgement):
            passed = True
            reasoning = None
        result_name = ('globalattr', 'acknowledgement', 'value')
        result = Result(BaseCheck.HIGH, passed, result_name, reasoning)

        ret_val.append(result)

        return ret_val

    def check_variables_long_name(self, dataset):
        """
        Check the every variable long name attribute and ensure it is string type.
        """
        ret_val = []
        for name, var in dataset.variables.iteritems():
            result_name = ('var', name, 'long_name', 'check_atttribute_type')
            reasoning = ["Attribute type is not string"]

            result = check_attribute_type((name,'long_name',),
                                             basestring,
                                             dataset,
                                             self.CHECK_VARIABLE_ATTRIBUTE,
                                             result_name,
                                             BaseCheck.HIGH,
                                             reasoning)
            ret_val.append(result)

        return ret_val

    def check_coordinate_variables(self, dataset):
        """
        Check all coordinate variables for
            numeric type (byte, float and integer)
            strictly monotonic values (increasing or decreasing)
        Also check that at least one of them is a spatial or temporal coordinate variable.
        """

        space_time_passed = False

        ret_val = []
        for var in self._coordinate_variables:
            result_name = ('var', 'coordinate_variable', var.name, 'check_variable_type')
            passed = True
            reasoning = None
            if not is_numeric(var.datatype):
                reasoning = ["Variable type is not numeric"]
                passed = False

            result = Result(BaseCheck.HIGH, passed, result_name, reasoning)
            ret_val.append(result)

            result_name = ('var', var.name, 'check_monotonic')
            passed = is_monotonic(var.__array__())
            reasoning = None

            if not passed:
                reasoning = ["Variable values are not monotonic"]

            result = Result(BaseCheck.HIGH, passed, result_name, reasoning)
            ret_val.append(result)

            if str(var.name) in _possibleaxis \
                or (hasattr(var, 'units') and (var.units in _possibleaxisunits or var.units.split(" ")[0]  in _possibleaxisunits)) \
                or hasattr(var,'positive'):
                space_time_passed = True


        result_name = ('var', 'coordinate_variable', 'space_time_coordinate_present')
        reasoning = None
        if not space_time_passed:
            reasoning = ["No space-time coordinate variable found"]
        result = Result(BaseCheck.HIGH, space_time_passed, result_name, reasoning)
        ret_val.append(result)

        return ret_val

    def check_time_variable(self, dataset):
        """
        Check time variable attributes:
            standard_name
            axis
            calendar
            valid_min
            valid_max
            type
            units
        """
        time_attributes = {
            'standard_name': ['time'],
            'axis': ['T'],
            'calendar': ['gregorian'],
            'valid_min': None,
            'valid_max': None,
        }

        ret_val = []

        if 'TIME' in dataset.variables:
            time_var = dataset.variables['TIME']

            result = Result(BaseCheck.MEDIUM, True, name=('var', 'TIME'))
            if time_var.dtype != np.float64:
                result.value = False
                result.msgs = ["The TIME variable should be of type double (64-bit)"]
            ret_val.append(result)

            ret_val.extend(
                check_attribute_dict(time_attributes, time_var)
            )

            ret_val.append(
                check_attribute('units', self.time_units, time_var, BaseCheck.MEDIUM)
            )

        return ret_val

    def check_longitude_variable(self, dataset):
        """
        Check longitude variable attributes:
            standard_name  value is 'longitude'
            axis   value is 'X'
            valid_min 0 or -180
            valid_max 360 or 180
            reference_datum is a string type
        """
        longitude_attributes = {
            'standard_name': ['longitude'],
            'axis': ['X'],
            'valid_min': None,
            'valid_max': None,
            'reference_datum': basestring,
        }

        longitude_units = ['degrees_east']

        valid_range_expected = ((0, 360), (-180, 180))

        ret_val = []

        if 'LONGITUDE' in dataset.variables:
            longitude_var = dataset.variables['LONGITUDE']

            result = Result(BaseCheck.MEDIUM, True, name=('var', 'LONGITUDE'))
            if longitude_var.dtype not in [np.float16, np.float32, np.float64, np.float128]:
                result.value = False
                result.msgs = ["The LONGITUDE variable should be of type double or float"]
            ret_val.append(result)

            ret_val.extend(
                check_attribute_dict(longitude_attributes, longitude_var)
            )

            ret_val.append(
                check_attribute('units', longitude_units, longitude_var, BaseCheck.MEDIUM)
            )

            valid_min = getattr(longitude_var, 'valid_min', None)
            valid_max = getattr(longitude_var, 'valid_max', None)
            if (valid_min, valid_max) not in valid_range_expected:
                result = Result(BaseCheck.HIGH, False, name=('var', 'LONGITUDE', 'valid_min/max'))
                result.msgs = ['(valid_min, valid_max) should be %s or %s' % valid_range_expected]
                ret_val.append(result)

        return ret_val

    def check_latitude_variable(self, dataset):
        """
        Check latitude variable attributes:
            standard_name  value is 'latitude'
            axis   value is 'Y'
            valid_min -90
            valid_max 90
            reference_datum is a string type
        """
        latitude_attributes = {
            'standard_name': ['latitude'],
            'axis': ['Y'],
            'valid_min': [-90],
            'valid_max': [ 90],
            'reference_datum': basestring,
        }
        latitude_units = ['degrees_north']

        ret_val = []

        if 'LATITUDE' in dataset.variables:
            latitude_var = dataset.variables['LATITUDE']

            result = Result(BaseCheck.MEDIUM, True, name=('var', 'LATITUDE'))
            if latitude_var.dtype not in [np.float16, np.float32, np.float64, np.float128]:
                result.value = False
                result.msgs = ["The LATITUDE variable should be of type double or float"]
            ret_val.append(result)

            ret_val.extend(
                check_attribute_dict(latitude_attributes, latitude_var)
            )

            ret_val.append(
                check_attribute('units', latitude_units, latitude_var, BaseCheck.MEDIUM)
            )

        return ret_val

    def check_vertical_variable(self, dataset):
        """
        Check vertical variable attributes:
            standard_name  value is 'depth' or 'height'
            axis = 'Z' (for at least one vertical variable in the file --
                        there are cases where CF does not allow multiple
                        variables with the same axis value)
            positive value is 'down' or "up"
            valid_min exist
            valid_max exists
            reference_datum is a string type
            unit
        """
        ret_val = []
        results_axis = []
        n_vertical_var = 0

        for name, var in dataset.variables.iteritems():
            var_type = vertical_coordinate_type(dataset, var)
            if var_type is None:
                # not a vertical variable
                continue

            n_vertical_var += 1
            result_name_std = ('var', name, 'standard_name', 'vertical')
            result_name_pos = ('var', name, 'positive', 'vertical')
            if var_type == 'unknown':
                # we only get this if var has axis='Z' but no valid
                # standard_name or positive attribute
                result = Result(BaseCheck.HIGH, False, result_name_std, \
                                ["Vertical coordinate variable (axis='Z') should have attribute" \
                                 " standard_name = 'depth' or 'height'"])
                ret_val.append(result)
                result = Result(BaseCheck.HIGH, False, result_name_pos, \
                                ["Vertical coordinate variable (axis='Z') should have attribute" \
                                 " positive = 'up' or 'down'"])
                ret_val.append(result)

            else:
                if var_type == 'height':
                    expected_positive = 'up'
                else:
                    expected_positive = 'down'

                reasoning = []
                valid = getattr(var, 'standard_name', '') == var_type
                if not valid:
                    reasoning = ["Variable %s appears to be a vertical coordinate, should have attribute" \
                                 " standard_name = '%s'" % (name, var_type)]
                result = Result(BaseCheck.HIGH, valid, result_name_std, reasoning)
                ret_val.append(result)

                reasoning = []
                valid = getattr(var, 'positive', '') == expected_positive
                if not valid:
                    reasoning = ["Variable %s appears to be a vertical coordinate, should have attribute" \
                                 " positive = '%s'" % (name, expected_positive)]
                result = Result(BaseCheck.HIGH, valid, result_name_pos, reasoning)
                ret_val.append(result)

            result_name = ('var', name, 'reference_datum', 'type')
            result = check_attribute_type((name, 'reference_datum'),
                                       basestring,
                                       dataset,
                                       self.CHECK_VARIABLE_ATTRIBUTE,
                                       result_name,
                                       BaseCheck.HIGH)
            ret_val.append(result)

            result_name = ('var', name, 'valid_min', 'present')
            result = check_present((name, 'valid_min'),
                                    dataset,
                                    self.CHECK_VARIABLE_ATTRIBUTE,
                                    result_name,
                                    BaseCheck.HIGH)
            ret_val.append(result)

            result_name = ('var', name, 'valid_max', 'present')
            result = check_present((name, 'valid_max'),
                                    dataset,
                                    self.CHECK_VARIABLE_ATTRIBUTE,
                                    result_name,
                                    BaseCheck.HIGH)
            ret_val.append(result)

            result_name = ('var', name, 'axis', 'vertical')
            axis = getattr(var, 'axis', '')
            if axis and axis == 'Z':
                result = Result(BaseCheck.HIGH, True, result_name, None)
                ret_val.append(result)
            else:
                reasoning = ["Variable %s appears to be a vertical coordinate, should have attribute" \
                             " axis = 'Z'" % name]
                result = Result(BaseCheck.HIGH, False, result_name, reasoning)
                if axis:
                    # axis attribute exists, incorrect value, so definitely report
                    ret_val.append(result)
                else:
                    # no axis attribute, which might be ok, review later
                    results_axis.append(result)

            result_name = ('var', name, 'units', 'vertical')
            reasoning = [" is not a valid CF distance unit"]
            reasoning = ["Variable %s appears to be a vertical coordinate, should have" \
                         " units of distance" % name]
            result = check_value((name,'units',),
                                    'meter',
                                    self.OPERATOR_CONVERTIBLE,
                                    dataset,
                                    self.CHECK_VARIABLE_ATTRIBUTE,
                                    result_name,
                                    BaseCheck.HIGH,
                                    reasoning)
            ret_val.append(result)

            result_name = ('var', name, 'variable_type')
            reasoning = ["Variable %s should have type Double or Float" % name]
            result = check_attribute_type((name,),
                                        [np.float64, np.float, np.float32, np.float16, np.float128],
                                        dataset,
                                        self.CHECK_VARIABLE,
                                        result_name,
                                        BaseCheck.MEDIUM,
                                        reasoning)
            ret_val.append(result)

        # if none of the vertical variables have axis='Z', report it
        if len(results_axis) == n_vertical_var:
            ret_val.extend(results_axis)

        return ret_val

    def check_variable_attribute_type(self, dataset):
        """
        Check variable attribute to ensure it has the same type as the variable
        """

        ret_val = []
        reasoning = ["Attribute type is not same as variable type"]
        for name,var in dataset.variables.iteritems():
            result_name = ('var', name, '_FillValue', 'check_attribute_type')
            result = check_attribute_type((name,'_FillValue',),
                                            var.datatype,
                                            dataset,
                                            self.CHECK_VARIABLE_ATTRIBUTE,
                                            result_name,
                                            BaseCheck.HIGH,
                                            reasoning,
                                            True)
            if not result is None:
                ret_val.append(result)

            result_name = ('var', name, 'valid_min', 'check_attribute_type')

            result = check_attribute_type((name,'valid_min',),
                                            var.datatype,
                                            dataset,
                                            self.CHECK_VARIABLE_ATTRIBUTE,
                                            result_name,
                                            BaseCheck.HIGH,
                                            reasoning,
                                            True)
            if not result is None:
                ret_val.append(result)

            result_name = ('var', name, 'valid_max', 'check_attribute_type')            
            result = check_attribute_type((name,'valid_max',),
                                                var.datatype,
                                                dataset,
                                                self.CHECK_VARIABLE_ATTRIBUTE,
                                                result_name,
                                                BaseCheck.HIGH,
                                                reasoning,
                                                True)
            if not result is None:
                ret_val.append(result)

        return ret_val

    def check_data_variable_present(self, dataset):
        """
        Check that there's at least one data variable exists in the file
        """
        result_name = ('var', 'data_variable_present')
        if not self._data_variables:
            result = Result(BaseCheck.HIGH, False, result_name, ["No data variable exists"])
        else:
            result = Result(BaseCheck.HIGH, True, result_name, None)

        return [result]

    def check_quality_control_conventions_for_quality_control_variable(self, dataset):
        """
        Check that the attribute quality_control_conventions
        is valid and consistent.
        """
        ret_val = []
        for var in self._quality_control_variables:
            ret_val.append(
                check_attribute('quality_control_conventions', self.quality_control_conventions,
                                var, priority=BaseCheck.MEDIUM)
            )
        return ret_val

    def check_quality_control_variable_matches_variable(self, dataset):
        """
        Check that the name of a quality control variable which is like <DATA>_quality_control
        and matches the name of a corresponding data variable <DATA>.
        """
        ret_val = []
        for qc_variable in self._quality_control_variables:
            result_name = ('qc_var', qc_variable.name, 'ends_in_quality_control')
            reasoning = ["the qc variable '%s' does not end in '_quality_control'" % qc_variable.name]
            qc_variable_root_name = re.findall('^(.*)_quality_control$', qc_variable.name)   # returns a list with the root names, if matched
            if qc_variable_root_name:
                reasoning = []
                qc_variable_root_name = qc_variable_root_name[0]

            result = Result(BaseCheck.HIGH, reasoning==[], result_name, reasoning)

            ret_val.append(result)

            if not qc_variable_root_name:
                continue

            result_name = ('qc_var', qc_variable.name, 'match_with_variable')
            reasoning = ["there is no data variable name '%s' for '%s'" % (qc_variable_root_name, qc_variable.name)]
            match = False
            if qc_variable_root_name in dataset.variables.keys():
                reasoning = []
                match = True

            result = Result(BaseCheck.HIGH, match, result_name, reasoning)
            
            ret_val.append(result)

        return ret_val

    def check_quality_control_variable_dimensions(self, dataset):
        """
        Check quality variable has same dimensions as the related data variable.
        """
        ret_val = []
        for qc_variable in self._quality_control_variables:
            for data_variable in self._data_variables:
                ancillary_variables = \
                find_ancillary_variables_by_variable(dataset, data_variable)
                if qc_variable in ancillary_variables:
                    result_name = ('var', 'quality_variable', qc_variable.name,\
                                    data_variable.name, 'check_dimension')
                    if data_variable.dimensions == qc_variable.dimensions:
                        result = Result(BaseCheck.HIGH, True, result_name, None)
                    else:
                        reasoning = ["Dimension is not same"]
                        result = Result(BaseCheck.HIGH, False, result_name, reasoning)

                    ret_val.append(result)

        return ret_val

    def check_quality_control_variable_listed(self, dataset):
        """
        Check quality control variable is listed in the related data variable's
        ancillary_variables attribute.
        """
        ret_val = []

        for quality_var in self._quality_control_variables:
            result_name = ('var', 'quality_variable', quality_var.name, 'check_listed')

            if quality_var in self._ancillary_variables:
                result = Result(BaseCheck.MEDIUM, True, result_name, None)
            else:
                reasoning = ["Quality variable is not listed in any data" \
                             " variable's ancillary_variables attribute"]
                result = Result(BaseCheck.MEDIUM, False, result_name, reasoning)

            ret_val.append(result)

        return ret_val

    def check_quality_control_variable_standard_name(self, ds):
        """
        Check quality control variable standard name attribute.
        """
        ret_val = []

        for qc_variable in self._quality_control_variables:
            for variable in ds.variables.values():
                ancillary_variables = find_ancillary_variables_by_variable(
                                        ds, variable)
                if qc_variable in ancillary_variables:
                    value = getattr(variable, 'standard_name', '')
                    result_name = ('var', 'quality_variable', qc_variable.name,\
                                    variable.name, 'check_standard_name')
                    if value:
                        value = value + ' ' + 'status_flag'
                        if getattr(qc_variable, 'standard_name', '') != value:
                            reasoning = ["Standard name should be '%s'." % value]
                            result = Result(BaseCheck.HIGH, False, result_name, reasoning)
                        else:
                            result = Result(BaseCheck.HIGH, True, result_name, None)
                    else:
                        result = Result(BaseCheck.HIGH, True, result_name, None)

                    ret_val.append(result)
        return ret_val

    def check_geospatial_vertical_units(self, dataset):
        """
        Check value of lgeospatial_vertical_units global attribute is valid CF depth
        unit, if exists
        """
        ret_val = []
        result_name = ('var', 'geospatial_vertical_units','check_attributes')
        reasoning = ["units is not a valid CF depth unit"]

        result = check_value(('geospatial_vertical_units',),
                                    'meter',
                                    self.OPERATOR_CONVERTIBLE,
                                    dataset,
                                    self.CHECK_GLOBAL_ATTRIBUTE,
                                    result_name,
                                    BaseCheck.HIGH,
                                    reasoning,
                                    True)

        if result is not None:
            ret_val.append(result)

        return ret_val



################################################################################
#
# IMOS 1.3 Checker
#
################################################################################

class IMOS1_3Check(IMOSBaseCheck):
    """Compliance-checker check suite for the IMOS netcdf conventions v1.3
    """
    register_checker = True
    _cc_spec_version = '1.3'

    def __init__(self):
        super(IMOS1_3Check, self).__init__()

        # Add global attribute requirements not in base checker
        self.mandatory_global_attributes.update({
            'data_centre': ['eMarine Information Infrastructure (eMII)',
                             'Australian Ocean Data Network (AODN)'],
            'data_centre_email': ['info@emii.org.au',
                                   'info@aodn.org.au'],
            'distribution_statement': '.*Data may be re-used, provided that related metadata explaining' \
                                       ' the data has been reviewed by the user, and the data is appropriately' \
                                       ' acknowledged. Data, products and services from IMOS are provided' \
                                       ' "as is" without any warranty as to fitness for a particular purpose.'
        })
        self.optional_global_attributes.update({
            'quality_control_set': [1, 2, 3, 4]
        })

    def check_data_variables(self, dataset):
        """
        Check that each data variable has a _FillValue attribute
        """
        ret_val = []
        for var in self._data_variables:
            ret_val.append(check_attribute('_FillValue', None, var))
        return ret_val



################################################################################
#
# IMOS 1.4 Checker
#
################################################################################

class IMOS1_4Check(IMOSBaseCheck):
    """Compliance-checker check suite for the IMOS netcdf conventions v1.4
    """
    register_checker = True
    _cc_spec_version = '1.4'
    _cc_authors =  "Marty Hidas"

    def __init__(self):
        super(IMOS1_4Check, self).__init__()

        # Update the global attribute requirements that have changed from IMOS-1.3
        self.mandatory_global_attributes.update({
            'data_centre': ['Australian Ocean Data Network (AODN)'],
            'data_centre_email': ['info@aodn.org.au'],
            'acknowledgement': 'Any users( \(including re-?packagers\))? of IMOS data( \(including re-?packagers\))? are required to clearly acknowledge the source of the material( derived from IMOS)? in (this|the) format: "Data was sourced from the Integrated Marine Observing System \(IMOS\) - IMOS is( a national collaborative research infrastructure,)? supported by the Australian Government',
            'disclaimer': '.*Data, products and services from IMOS are provided "as is" without any warranty as to fitness for a particular purpose\.',
            'license': ['http://creativecommons.org/licenses/by/4.0/'],
            'standard_name_vocabulary': 'NetCDF Climate and Forecast \(CF\) Metadata Convention Standard Name Table (Version |v)?\d+',
        })

        self.time_units = '.*UTC'

        self.quality_control_conventions = [
            "IMOS standard flags",
            "ARGO quality control procedure",
            "BOM (SST and Air-Sea flux) quality control procedure",
            "WOCE quality control procedure"
        ]

    def check_geospatial_vertical_positive(self, dataset):
        """
        Check that global attribute geospatial_vertical_positive exists, if
        there is any vertical information in the file (i.e. a vertical variable,
        or attributes geospatial_vertical_min/max).
        Only applies to discrete sampling geometry (DSG) files, i.e. those with
        a featureType attribute.
        """
        ret_val = []

        # identify vertical vars
        vert_vars = [v for v in dataset.variables.itervalues() \
                             if vertical_coordinate_type(dataset, v) is not None]

        vert_min = getattr(dataset, 'geospatial_vertical_min', None)
        vert_max = getattr(dataset, 'geospatial_vertical_max', None)

        if hasattr(dataset, 'featureType') and(vert_vars or vert_min or ver_max):
            ret_val.append(
                check_attribute('geospatial_vertical_positive', None, dataset)
            )

        return ret_val

    def check_vertical_variable_reference_datum(self, dataset):
        """
        Check that the reference_datum attribute of any vertical variables has
        one of the 4 accpeted values:
        'Mean Sea Level (MSL)', 'sea surface', 'sea bottom', 'sensor'
        """
        ret_val = []
        accepted_values = ['Mean Sea Level (MSL)',
                           'sea surface',
                           'sea bottom',
                           'sensor']

        for name, var in dataset.variables.iteritems():
            var_type = vertical_coordinate_type(dataset, var)
            if var_type is None:
                # not a vertical variable
                continue

            ret_val.append(
                check_attribute('reference_datum', accepted_values, var)
            )

        return ret_val

    def check_data_variables(self, dataset):
        """
        Check that each data variable has the required attributes:
        - units
        - coordinates (must be a blank-separated list of valid variable names)
        """
        ret_val = []

        for var in self._data_variables:
            ret_val.append(check_attribute('units', None, var))

            result = check_attribute('coordinates', None, var)
            if result.value:
                for name in var.coordinates.split(' '):
                    if name not in dataset.variables:
                        result.value = False
                        result.msgs = ['Coordinates attribute must contain a blank-separated '\
                                       'list of valid variable names']
                        break

            ret_val.append(result)

        return ret_val

    def check_fill_value(self, dataset):
        """
        For every variable that has a _FillValue attribute, check that its
        value is not NaN.

        """
        ret_val = []
        for name, var in dataset.variables.iteritems():
            if not hasattr(var, '_FillValue'):
                continue

            result = Result(BaseCheck.MEDIUM, True, ('var', name, '_FillValue'))
            if np.isnan(var._FillValue):
                result.value = False
                result.msgs = [
                    "Attribute %s:_FillValue must have a real numeric value, not NaN" % name
                ]
            ret_val.append(result)

        return ret_val

    def check_coordinate_variable_no_fill_value(self, dataset):
        """
        Check that coordinate variables do NOT have a _FillValue attribute
        (as they should not have any missing values).

        """
        ret_val = []
        for var in self._coordinate_variables:
            result = Result(BaseCheck.HIGH, True, ('var', var.name, 'no _FillValue'))
            if hasattr(var, '_FillValue'):
                result.value = False
                result.msgs = [
                    'Coordinate variable %s should NOT have a _FillValue attribute, ' \
                    'as it is not allowed to have missing values' % var.name
                ]
            ret_val.append(result)

        return ret_val

    def check_quality_control_global(self, dataset):
        """
        For each quality control variable, if either of the attributes
        - quality_control_global
        - quality_control_global_conventions
        are present, check that they are BOTH present and have string values.

        """
        ret_val = []
        for var in self._quality_control_variables:
            if not hasattr(var, 'quality_control_global') and \
               not hasattr(var, 'quality_control_global_conventions'):
                continue

            ret_val.append(
                check_attribute('quality_control_global', basestring,
                                var, priority=BaseCheck.MEDIUM)
            )
            ret_val.append(
                check_attribute('quality_control_global_conventions', basestring,
                                var, priority=BaseCheck.MEDIUM)
            )

        return ret_val
