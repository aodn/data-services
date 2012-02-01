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
        self._F = nc.NetCDFFile(filename, 'w')
        self.dimensions = self._F.dimensions
        self.variables = {}  # this will not be the same as _F.variables

        # Create mandatory global attributes
        self._F.project = 'Integrated Marine Observing System (IMOS)'
        self._F.conventions = 'IMOS-1.3'
        self._F.naming_authority = 'IMOS'
        self._F.data_centre = 'eMarine Information Infrastructure (eMII)'
        self._F.data_centre_email = 'info@emii.org.au'
        self._F.netcdf_version = 3.6

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


    def setAttributes(self, var=None, **attr):
        """
        Add each keyword argument as an attribute to variable var. If
        var is not specified, add attr as global attributes.
        """
        base = 'self._F.'
        if var: base += 'variables[var].'
        for k, v in attr.items():
            exec base + k + ' = v'


    def createTime(self, times):
        """
        Create the TIME dimension from values given in a numpy ndarray.
        """
        # check and format time values?
        tlen = len(times)
        ttype = times.dtype.char  #  or force 'd'?
        # create the dimention
        self._F.createDimension('TIME', tlen)
        # create the corresponding variable and attributes
        self.time = self._F.createVariable('TIME', ttype, ('TIME',))
        self.time.standard_name = 'time'
        self.time.long_name = 'time'
        self.time.units = 'days since 1950-01-01T00:00:00Z'
        self.time.axis = 'T'
        self.time.valid_min  = 0
        self.time.valid_max  = 90000.0
        # self.time._FillValue = 99999.0    not needed for dimensions!
        self.time.calendar = 'gregorian'
          # self.time.quality_control_set = 1
        # add time vaules
        self.time[:] = times

    def createDepth(self, array):
        "Create the DEPTH dimension from values given in array."
        alen = len(array)
        atype = array.dtype.char  #  or force 'd'?
        # create the dimention
        self._F.createDimension('DEPTH', alen)
        # create the corresponding variable and attributes
        self.depth = self._F.createVariable('DEPTH', atype, ('DEPTH',))
        self.depth.standard_name = 'depth'
        self.depth.long_name = 'depth'
        self.depth.units = 'metres'
        self.depth.axis = 'Z'
        self.depth.positive = 'down'
        self.depth.valid_min  = 0
        self.depth.valid_max  = 12000.
          # self.depth.quality_control_set = 1
          # self.depth.uncertainty
          # self.depth.reference_datum = 'surface'
        # add depth vaules
        self.depth[:] = array




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

    def setAttributes(self, **attr):
        "Add each keyword argument as an attribute to the variable."
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
