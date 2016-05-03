''' Provide helper methods for IMOSChecker class
'''
import datetime

import numpy as np
import re

from numpy import amax
from numpy import amin


from compliance_checker.base import BaseCheck
from compliance_checker.base import Result
from compliance_checker.cf.util import units_convertible

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

def is_monotonic(array):
    """
    Check whether an array is strictly monotonic
    """
    diff = np.diff(array)
    return np.all(diff < 0) or np.all(diff > 0)

def is_valid_email(email):
    """Email validation, checks for syntactically invalid email"""

    emailregex = \
        "^.+\\@(\\[?)[a-zA-Z0-9\\-\\.]+\\.([a-zA-Z]{2,3}|[0-9]{1,3\})(\\]?)$"

    if re.match(emailregex, email) != None:
        return True

    return False

def is_numeric(variable_type):
    """
    Check whether a numpy type is numeric type (byte,
    float and integer)
    """
    float_type = [np.float16, np.float32, np.float64, np.float128]
    integer_type = [np.int, np.int8, np.int16, np.int32, np.int64]

    if variable_type == np.double:
        return True

    if variable_type in integer_type:
        return True

    if variable_type == np.byte:
        return True

    if variable_type in float_type:
        return True

    return False

def vertical_coordinate_type(dataset, variable):
    """Return None if the given variable does not appear to be a vertical
    coordinate. Otherwise return the likely type of the coordinate
    ('height', 'depth' or 'unknown'). A type is returned if the
    variable is not listed as an ancillary variable and meets any 
    of the conditions:
      * variable name includes 'depth' or 'height' (case-insensitive),
        but not 'quality_control'
      * standard_name is 'depth' or 'height'
      * positive attribute is 'up' or 'down'
      * axis is 'Z' (type is then 'unknown')

    """

    ancillary_variables = find_ancillary_variables(dataset.dataset)
    # skip ancillary variables
    if variable in ancillary_variables:
        return None

    name = getattr(variable, 'name', '')

    # skip QC variables
    if name.endswith('_quality_control'):
        return None

    if 'depth' in name.lower():
        return 'depth'
    if 'height' in  name.lower():
        return 'height'

    standard_name = getattr(variable, 'standard_name', '')
    if standard_name in ('depth', 'height'):
        return standard_name

    positive = getattr(variable, 'positive', '')
    if positive == 'down':
        return 'depth'
    if positive == 'up':
        return 'height'

    if getattr(variable, 'axis', '') == 'Z':
        return 'unknown'

    return None


def find_variables_from_attribute(dataset, variable, attribute_name):
    ''' Get variables based on a variable attribute such as coordinates.
    '''
    variables = []
    variable_names = getattr(variable, attribute_name, None)

    if variable_names is not None:
        for variable_name in variable_names.split(' '):
            if dataset.variables.has_key(variable_name):
                variable = dataset.variables[variable_name]
                variables.append(variable)

    return variables

def find_auxiliary_coordinate_variables(dataset):
    ''' Find all ancillary variables associated with a variable.
    '''
    auxiliary_coordinate_variables = []

    for name, var in dataset.variables.iteritems():
        auxiliary_coordinate_variables.extend(\
            find_variables_from_attribute(dataset, var, 'coordinates'))

    return auxiliary_coordinate_variables

def find_ancillary_variables_by_variable(dataset, variable):
    ''' Find all ancillary variables associated with a variable.
    '''
    return find_variables_from_attribute(dataset, variable, 'ancillary_variables')

def find_ancillary_variables(dataset):
    ''' Find all ancillary variables.
    '''
    ancillary_variables = []

    for name, var in dataset.variables.iteritems():
        ancillary_variables.extend(find_variables_from_attribute(dataset, var, \
                                     'ancillary_variables'))

    return ancillary_variables

def find_data_variables(dataset, coordinate_variables, ancillary_variables):
    """
        Finds all variables that could be considered Data variables.

        Returns a dictionary mapping name -> variable.

        Excludes variables that are:
            - coordinate variables
            - ancillary variables
            - no dimensions

        Results are NOT CACHED.
        """
    data_variables = []
    auxiliary_coordinate_variables = find_auxiliary_coordinate_variables(dataset)

    for name, var in dataset.variables.iteritems():
        if var not in coordinate_variables and var not in \
            ancillary_variables and var.dimensions and var not in \
            auxiliary_coordinate_variables \
            and is_numeric(var.dtype):

            data_variables.append(var)

    return data_variables

def find_quality_control_variables(dataset):
    ''' Find all quality control variables in a given netcdf file
    '''
    quality_control_variables = []

    for name, var in dataset.variables.iteritems():
        if name.endswith('_quality_control'):
            quality_control_variables.append(var)
            continue

        standard_name = getattr(var, 'standard_name', None)
        if standard_name is not None and standard_name.endswith('status_flag'):
            quality_control_variables.append(var)
            continue

        long_name = getattr(var, 'long_name', None)
        if long_name is not None and isinstance(long_name, basestring):
            if 'status_flag' in long_name or 'quality flag' in long_name:
                quality_control_variables.append(var)
                continue

        if hasattr(var, 'quality_control_conventions'):
            quality_control_variables.append(var)
            continue

    return quality_control_variables

def check_present(name, data, check_type, result_name, check_priority, reasoning=None):
    """
    Help method to check whether a variable, variable attribute
    or a global attribute presents.

    params:
        name (tuple): variable name and attribute name.
                        For global attribute, only attribute name present.
        data (Dataset): netcdf data file
        check_type (int): CHECK_VARIABLE, CHECK_GLOBAL_ATTRIBUTE,
                        CHECK_VARIABLE_ATTRIBUTE
        result_name: the result name to display
        check_priority (int): the check priority
        reasoning (str): reason string for failed check
    return:
        result (Result): result for the check
    """
    passed = True
    reasoning_out = None

    if check_type == CHECK_GLOBAL_ATTRIBUTE:
        result_name_out = result_name or ('globalattr', name[0],'present')
        if name[0] not in data.dataset.ncattrs():
            reasoning_out = reasoning or ["Attribute %s not present" % name[0]]
            passed = False

    if check_type == CHECK_VARIABLE or\
        check_type == CHECK_VARIABLE_ATTRIBUTE:
        result_name_out = result_name or ('var', name[0],'present')

        variable = data.dataset.variables.get(name[0], None)

        if variable == None:
            reasoning_out = reasoning or ['Variable %s not present' % name[0]]
            passed = False

        elif check_type == CHECK_VARIABLE_ATTRIBUTE:
                result_name_out = result_name or ('var', name[0], name[1], 'present')
                if name[1] not in variable.ncattrs():
                    reasoning_out = reasoning or ["Variable attribute %s:%s not present" % tuple(name)]
                    passed = False

    result = Result(check_priority, passed, result_name_out, reasoning_out)

    return result

def check_value(name, value, operator, ds, check_type, result_name, check_priority, reasoning=None, skip_check_present=False):
    """
    Help method to compare attribute to value or a variable
    to a value. It also returns a Result object based on whether
    the check is successful or not.

    params:
        name (tuple): variable name and attribute name.
                      For global attribute, only attribute name present.
        value (str): expected value
        operator (int): OPERATOR_EQUAL, OPERATOR_MAX, OPERATOR_MIN
        ds (Dataset): netcdf data file
        check_type (int): CHECK_VARIABLE, CHECK_GLOBAL_ATTRIBUTE,
                          CHECK_VARIABLE_ATTRIBUTE
        result_name: the result name to display
        check_priority (int): the check priority
        reasoning (str): reason string for failed check
        skip_check_present (boolean): flag to allow check only performed
                                     if attribute is present
    return:
        result (Result): result for the check
    """
    result = check_present(name, ds, check_type,
                           result_name,
                           check_priority)

    if result.value:
        result = None
        retrieved_value = None
        passed = True
        reasoning_out = None

        if check_type == CHECK_GLOBAL_ATTRIBUTE:
            retrieved_value = getattr(ds.dataset, name[0])
            retrieved_name = name[0]

        if check_type == CHECK_VARIABLE:
            variable = ds.dataset.variables.get(name[0], None)
            retrieved_name = name[0]

        if check_type == CHECK_VARIABLE_ATTRIBUTE:
            variable = ds.dataset.variables.get(name[0], None)
            retrieved_value = getattr(variable, name[1])
            retrieved_name = '%s:%s' % name

        if operator == OPERATOR_EQUAL:
            if retrieved_value != value:
                passed = False
                reasoning_out = reasoning or \
                                ["Attribute %s should be equal to '%s'" % (retrieved_name, str(value))]

        if operator == OPERATOR_MIN:
            min_value = amin(variable.__array__())

            if not np.isclose(min_value, float(value)):
                passed = False
                reasoning_out = reasoning or \
                                ["Minimum value of %s (%f) does not match attributes (%f)" % \
                                 (retrieved_name, min_value, float(value))]

        if operator == OPERATOR_MAX:
            max_value = amax(variable.__array__())
            if not np.isclose(max_value, float(value)):
                passed = False
                reasoning_out = reasoning or \
                                ["Maximum value of %s (%f) does not match attributes (%f)" % \
                                 (retrieved_name, max_value, float(value))]

        if operator == OPERATOR_DATE_FORMAT:
            try:
                datetime.datetime.strptime(retrieved_value, value)
            except ValueError:
                passed = False
                reasoning_out = reasoning or \
                                ["Attribute %s is not in correct date/time format (%s)" % \
                                 (retrieved_name, value)]

        if operator == OPERATOR_SUB_STRING:
            if value not in retrieved_value:
                passed = False
                reasoning_out = reasoning or \
                                ["Attribute %s should contain the substring '%s'" % \
                                 (retrieved_name, value)]

        if operator == OPERATOR_CONVERTIBLE:
            if not units_convertible(retrieved_value, value):
                passed = False
                reasoning_out = reasoning or \
                                ["Units %s should be equivalent to %s" % (retrieved_name, value)]

        if operator == OPERATOR_EMAIL:
            if not is_valid_email(retrieved_value):
                passed = False
                reasoning_out = reasoning or ["Attribute %s is not a valid email address" % \
                                              retrieved_name]

        if operator == OPERATOR_WITHIN:
            if retrieved_value not in value:
                passed = False
                reasoning_out = reasoning or ["Attribute %s is not in the expected range (%s)" % \
                                              (retrieved_name, str(value))]

        result = Result(check_priority, passed, result_name, reasoning_out)

    else:
        if skip_check_present:
            result = None

    return result

def check_attribute_type(name, expected_type, ds, check_type, result_name, check_priority, reasoning=None, skip_check_present=False):
    """
    Check global data attribute and ensure it has the right type.
    params:
        name (tuple): attribute name
        expected_type (class): expected type
        ds (Dataset): netcdf data file
        check_type (int): CHECK_VARIABLE, CHECK_GLOBAL_ATTRIBUTE,
                          CHECK_VARIABLE_ATTRIBUTE
        result_name: the result name to display
        check_priority (int): the check priority
        reasoning (str): reason string for failed check
        skip_check_present (boolean): flag to allow check only performed
                                     if attribute is present
    return:
        result (Result): result for the check
    """
    result = check_present(name, ds, check_type,
                           result_name,
                           BaseCheck.HIGH)

    if result.value:
        if check_type == CHECK_GLOBAL_ATTRIBUTE:
            attribute_value = getattr(ds.dataset, name[0])
            attribute_name = 'Attribute ' + name[0]

        if check_type == CHECK_VARIABLE_ATTRIBUTE:
            attribute_value = getattr(ds.dataset.variables[name[0]], name[1])
            attribute_name = 'Attribute %s:%s' % name

        if check_type == CHECK_VARIABLE:
            attribute_value = ds.dataset.variables[name[0]]
            attribute_name = 'Variable ' + name[0]

        dtype = getattr(attribute_value, 'dtype', None)
        passed = True

        if dtype is not None:
            if type(expected_type) is list:
                if dtype not in expected_type:
                    passed = False

            elif dtype != expected_type:
                passed = False
        else:
            try:
                if not isinstance(attribute_value, expected_type):
                    passed = False
            except TypeError:
                passed = False

        if not passed:
            if not reasoning:
                reasoning = ["%s should have type %s" % (attribute_name, str(expected_type))]
            result = Result(check_priority, False, result_name, reasoning)
        else:
            result = Result(check_priority, True, result_name, None)
    else:
        if skip_check_present:
            result = None

    return result
