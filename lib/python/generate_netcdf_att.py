#!/usr/bin/env python
"""
Module to generate global attributes and variable attributes of a netcdf file
by reading a conf file.

Attributes from the conf file will always be overwritten with attributes found
in imosParameters.txt for a variable

generate_netcdf_att(netcdf4_obj, conf_file)

Attributes:
    netcdf4_obj: the netcdf object in write mode created by
         netCDF4.Dataset(netcdf_file_path, "w", format="NETCDF4")
    conf_file: a config text file readable by ConfigParser module

WHAT THIS DOES NOT DO :
    * This does not create dimensions, variables
    * This does not add the _FillValue attribute


Example of a conf_file:
-----------------------------------------------
[global_attributes]
abstract         = CTD Satellite
acknowledgement  = Data was sourced
author_name      = Besnard, Laurent

[TIME]
units         = days since 1950-01-01 00:00:00
standard_name = time
long_name     = analysis_time

-----------------------------------
author: Besnard, Laurent
email : laurent.besnard@utas.edu.au
"""

from ConfigParser import SafeConfigParser
from IMOSnetCDF import *
from numpy import float32


def get_imos_parameter_info(nc_varname, *var_attname):
    """
    retrieves the attributes for an IMOS parameter by looking at
    imosParameters.txt
    Also can retrieve the attribute value only if specified
    if the variable or att is not found, returns []
    """

    imos_var_attr = attributesFromIMOSparametersFile()
    try:
        varname_attr = imos_var_attr[nc_varname]
    except:
        # variable not in imosParameters.txt
        return []

    # handle optional argument varatt to return the attvalue of one attname
    # only
    for att in var_attname:
        try:
            return varname_attr[att]
        except:
            return []

    return varname_attr

def _find_var_conf(parser):
    """
    list NETCDF variable names from conf file
    """

    variable_list = parser.sections()
    if 'global_attributes' in variable_list:
        variable_list.remove('global_attributes')

    return variable_list

def _setup_var_att(nc_varname, netcdf4_obj, parser):
    """
    find the variable name from var_object which is equal to the category name
    of the conf file.

    parse this variable name category as a dictionnary, and creates for the
    variable object "var_object" the attributes and its corresponding values.
    This function requires the netcdf object to be already open with Dataset
    from netCDF4 module
    """

    var_object        = netcdf4_obj[nc_varname]
    var_atts          = dict(parser.items(nc_varname)) # attr from conf file
    # attr from imosParameters.txt
    varname_imos_attr = get_imos_parameter_info(nc_varname)

    # set up attributes according to conf file
    for var_attname, var_attval in var_atts.iteritems():
        setattr(var_object, var_attname, _real_type_value(var_attval))

    # overwrite if necessary with correct values from imosParameters.txt so this
    # file is ALWAYS the point of truth
    def _set_imos_var_att_if_exist(attname):
        try:
            #precautious. issue with netcdf lib to overwrite unicodes attvalues *** RuntimeError: NetCDF: Attribute not found
            if hasattr(var_object, attname):
                delattr(var_object, attname)

            if (varname_imos_attr['__data_type'] == 'f') and type(varname_imos_attr[attname])  == float:
                setattr(var_object, attname, float32(varname_imos_attr[attname]))
            else:
                setattr(var_object, attname, varname_imos_attr[attname])

        except:
            pass

    if varname_imos_attr :
        _set_imos_var_att_if_exist('standard_name')
        _set_imos_var_att_if_exist('long_name')
        _set_imos_var_att_if_exist('units')
        _set_imos_var_att_if_exist('valid_min')
        _set_imos_var_att_if_exist('valid_max')

def _setup_gatts(netcdf_object, parser):
    """
    read the "global_attributes" from gatts.conf and create the global
    attributes from an already opened netcdf_object
    """

    gatts = dict(parser.items('global_attributes'))
    for gattname, gattval in gatts.iteritems():
        setattr(netcdf_object, gattname, _real_type_value(gattval))

def _call_parser(conf_file):
    parser = SafeConfigParser()
    parser.optionxform = str # to preserve case
    parser.read(conf_file)
    return parser

def _real_type_value(s):
    try:
        return int(s)
    except :
        pass

    try:
        return float(s)
    except :
        pass

    return str(s)

def generate_netcdf_att(netcdf4_obj, conf_file):
    """
    main function to generate the attributes of a netCDF file
    """
    if not isinstance(netcdf4_obj, object):
        raise ValueError('%s is not a netCDF4 object' % netcdf4_obj)

    if not os.path.exists(conf_file):
        raise ValueError('%s file does not exist' % conf_file)

    parser = _call_parser(conf_file)
    _setup_gatts(netcdf4_obj, parser)

    variable_list = _find_var_conf(parser)
    for var in variable_list:
        # only create attributes for variable which already exist
        if var in netcdf4_obj.variables.keys():
            _setup_var_att(var, netcdf4_obj, parser)
