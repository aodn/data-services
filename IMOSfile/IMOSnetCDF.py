#! /usr/bin/env python
#
# Python module to manage IMOS-standard netCDF data files.


# Functionality to be added:

# add attributes and data to an open file (auto-filling as many of the
# attributes as possible)

# check that a given file is written according to the IMOS convention,

# check that the filename meets the convention and matches information
# within the file.


import Scientific.IO.NetCDF as nc
import numpy as np



#############################################################################

# define default global and variable attributes
defaultAttributes = {
    'global': [
        'project = "Integrated Marine Observing System (IMOS)"',
        'conventions = "CF-1.6, IMOS-1.3"',
        'naming_authority = "IMOS"',
        'data_centre = "eMarine Information Infrastructure (eMII)"',
        'data_centre_email = "info@emii.org.au"',
        'netcdf_version = 3.6',
        ],
    'TIME': [
        'standard_name = "time"',
        'long_name = "time"',
        'units = "days since 1950-01-01T00:00:00Z"',
        'axis = "T"',
        'valid_min = 0',
        'valid_max = 90000.0',
        'calendar = "gregorian"'
        ],
    'LATITUDE': [
        'long_name = "latitude"',
        'units = "degrees north"',
        ],
    'LONGITUDE': [
        'long_name = "longitude"',
        'units = "degrees east"',
        ],
    'DEPTH': []
    }



#############################################################################

class IMOSnetCDFFile(object):
    """
    netCDF file following the IMOS netCDF conventions.

    Based on the IMOS NetCDF User Manual (v1.3) and File Naming
    Convention (v1.3), which can be obtained from
    http://imos.org.au/facility_manuals.html
    """

    def __init__(self, filename):
        """
        Create a new empty file, pre-filling some mandatory global attributes.
        """

        # Open the file and create dimension and variable lists
        self.__dict__['_F'] = nc.NetCDFFile(filename, 'w')
        self.__dict__['dimensions'] = self._F.dimensions
        self.__dict__['variables'] = {}  # this will not be the same as _F.variables

        # Create mandatory global attributes
        if defaultAttributes.has_key('global'):
            self.setAttributes(defaultAttributes['global'])


    def __getattr__(self, name):
        "Return the value of a global attribute."
        return self._F.__dict__[name]


    def __setattr__(self, name, value):
        "Set a global attribute."
        exec 'self._F.' + name + ' = value'


    def close(self):
        "Write all data to the file and close."
        self._F.close()


    def createDimension(self, name, length):
        "Create a new dimension."
        self._F.createDimension(name, length)


    def createVariable(self, name, type, dimensions):
        """
        Create a new variable in the file. 
        Returns an IMOSNetCDFVariable object.
        """
        newvar = IMOSnetCDFVariable(self._F.createVariable(name, type, dimensions))
        self.variables[name] = newvar
        return newvar

        
    def sync(self):
        "Write all buffered data to the disk file."
        self._F.sync()

    flush = sync


    def getAttributes(self):
        "Return the global attributes of the file as a dictionary."
        return self._F.__dict__


    def setAttributes(self, alist=[], **attr):
        """
        Set global attributes from a list of 'name = value'
        strings. Note that string-valued attributes need to be quoted
        within the string, e.g. 'axis = "T"'.

        Any additional keyword arguments are also added as attributes
        (order not preserved).
        """
        for line in alist:
            exec 'self._F.' + line
        for k, v in attr.items():
            exec 'self._F.' + k + ' = v'


    def setDimension(self, name, values):
        """
        Create a dimension with the given name and values, and return
        the corresponding IMOSnetCDFVariable object.

        For the standard dimensions TIME, LATITUDE, LONGITUDE, and
        DEPTH, the mandatory attributes will be set.
        """
        
        # make sure input values are in an numpy array (even if only one value)
        varray = np.array(values)

        # create the dimension
        self._F.createDimension(name, varray.size)

        # create the corresponding variable and add the values
        var = self.createVariable(name, varray.dtype.char, (name,))
        var[:] = values

        # add attributes
        if defaultAttributes.has_key(name):
            var.setAttributes(defaultAttributes[name])

        return var





#############################################################################

class IMOSnetCDFVariable(object):
    """
    Variable in an IMOS netCDF file.

    This is just a wrapper for the Scientific.IO.NetCDF.NetCDFVariable
    class and has similar functionality. Variable attributes can also
    be accessed via the getAttributes() and setAttributes() methods.
    """

    def __init__(self, ncvar):
        """
        Creates a new object to represent the given NetCDFVariable.
        For internal use by IMOSnetCDFFile methods only.
        """
        self.__dict__['_V'] = ncvar
        self.__dict__['shape'] = ncvar.shape
        self.__dict__['dimensions'] = ncvar.dimensions


    def __getattr__(self, name):
        "Return the value of a variable attribute."
        return self._V.__dict__[name]


    def __setattr__(self, name, value):
        "Set an attribute of the variable."
        exec 'self._V.' + name + ' = value'


    def __getitem__(self, key):
        "Return (any slice of) the variable values."
        return self._V[key]


    def __setitem__(self, key, value):
        "Set (any slice of) the variable values."
        self._V[key] = value


    def getAttributes(self):
        "Return the attributes of the variable."
        return self._V.__dict__


    def setAttributes(self, alist=[], **attr):
        """
        Set variable attributes from a list of 'name = value'
        strings. Note that string-valued attributes need to be quoted
        within the string, e.g. 'axis = "T"'.  

        Any additional keyword arguments are also added as attributes
        (order not preserved).
        """
        for line in alist:
            exec 'self._V.' + line
        for k, v in attr.items():
            exec 'self._V.' + k + ' = v'

            
    def getValue(self):
        "Return the value of the variable."
        return self._V.getValue()

            
    def setValue(self, value):
        "Assign a value to the variable."
        self._V.assignValue(value)


    def typecode(self):
        "Returns the variable's type code (single character)."
        return self._V.typecode()
