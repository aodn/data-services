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
from datetime import datetime, timedelta
import os, re, time


#############################################################################

# File containing default attributes that apply to all netCDF files (loaded later).
baseAttributesFile = '/home/marty/work/code/IMOSfile/IMOSattributes.txt'
defaultAttributes = {}

# Epoch for time variabe
epoch = datetime(1950,1,1) 


#############################################################################

class IMOSnetCDFFile(object):
    """
    netCDF file following the IMOS netCDF conventions.

    Based on the IMOS NetCDF User Manual (v1.3) and File Naming
    Convention (v1.3), which can be obtained from
    http://imos.org.au/facility_manuals.html
    """

    def __init__(self, filename='', attribFile=None):
        """
        Create a new empty file, pre-filling some mandatory global
        attributes.  If filename is not given, a temporary file is
        opened, which can be renamed after closing.
        Optionally a file listing global and variable attributes can be given.
        """

        # Create temporary filename if needed
        if filename=='':
            filename = 'tmp_new_file.nc'
            # print 'IMOSnetCDF: using temporary filename '+filename
            self.__dict__['tmpFile'] = filename
        
        # Open the file and create dimension and variable lists
        self.__dict__['filename'] = filename
        self.__dict__['_F'] = nc.NetCDFFile(filename, 'w')
        self.__dict__['dimensions'] = self._F.dimensions
        self.__dict__['variables'] = {}  # this will not be the same as _F.variables
        if attribFile:
            self.__dict__['attributes'] = attributesFromFile(attribFile, defaultAttributes)
        else:
            self.__dict__['attributes'] = defaultAttributes
            

        # Create mandatory global attributes
        if self.attributes.has_key('global'):
            self.setAttributes(self.attributes['global'])


    def __getattr__(self, name):
        "Return the value of a global attribute."
        return self._F.__dict__[name]


    def __setattr__(self, name, value):
        "Set a global attribute."
        exec 'self._F.' + name + ' = value'


    def close(self):
        """
        Update global attributes, write all data to the file and close.
        Rename the file if a temporary file was used.
        """
        self.updateAttributes()
        self.date_created = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        self._F.close()
        if self.__dict__.has_key('tmpFile'):
            os.rename(self.tmpFile, self.filename)
        print 'IMOSnetCDF: wrote ' + self.filename


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
        "Update global attributes and write all buffered data to the disk file."
        self.updateAttributes()
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


    def updateAttributes(self):
        """
        Based on the dimensions and variables that have been set,
        update global attributes such as geospatial_min/max and
        time_coverage_start/end.
        """

        # TIME
        if self.variables.has_key('TIME'):
            times = self.variables['TIME'].getValue()
            self.time_coverage_start = (epoch + timedelta(times.min())).isoformat() + 'Z'
            self.time_coverage_end   = (epoch + timedelta(times.max())).isoformat() + 'Z'

        # LATITUDE
        if self.variables.has_key('LATITUDE'):
            lat = self.variables['LATITUDE'].getValue()
            self.geospatial_lat_min = lat.min()
            self.geospatial_lat_max = lat.max()

        # LONGITUDE
        if self.variables.has_key('LONGITUDE'):
            lon = self.variables['LONGITUDE'].getValue()
            self.geospatial_lon_min = lon.min()
            self.geospatial_lon_max = lon.max()


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
        if self.attributes.has_key(name):
            var.setAttributes(self.attributes[name])

        return var


    def setVariable(self, name, values, dimensions):
        """
        Create a variable with the given name, values and dimensions,
        and return the corresponding IMOSnetCDFVariable object.
        """
        
        # make sure input values are in an numpy array (even if only one value)
        varray = np.array(values)

        ### should add check that values has the right shape for dimensions !!

        # create the variable
        var = self.createVariable(name, varray.dtype.char, dimensions)

        # add the values
        var[:] = values

        # add attributes
        if self.attributes.has_key(name):
            var.setAttributes(self.attributes[name])

        return var


    def standardFileName(self, datacode='', product='', path='', rename=True):
        """
        Create an IMOS-standard (v1.3) name for the file based on the
        current attributes and variables in the file and return as a
        string. updateAttributes() should be run first.

        If path is given, it is added to the beginning of the file name.

        If rename is True, the file will be renamed to the standard name upon close().
        """

        globalattr = self.getAttributes()

        name = path+'IMOS'

        # facility code
        assert globalattr.has_key('institution'), 'standardFileName: institution attribute not set!'
        name += '_' + self.institution

        # data code
        if datacode:
            name += '_' + datacode

        # start date
        assert globalattr.has_key('time_coverage_start'), 'standardFileName: time_coverage_start not set!'
        name += '_' + re.sub('[-:]', '', self.time_coverage_start)
        
        # site code
        assert globalattr.has_key('site_code'), 'standardFileName: site_code not set!'
        name += '_' + self.site_code

        # file version
        assert globalattr.has_key('file_version'), 'standardFileName: file_version not set!'
        name += '_' + 'FV0%d' % ('1' in self.file_version)

        # product type
        if product:
            name += '_'+product

        # end date
        assert globalattr.has_key('time_coverage_end'), 'standardFileName: time_coverage_end not set!'
        name += '_END-' + re.sub('[-:]', '', self.time_coverage_end)

        # creation date
        now = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
        name += '_C-' + now

        # extension
        name += '.nc'

        if rename:
            self.__dict__['filename'] = name
       
        return name



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



#############################################################################

def attributesFromFile(filename, inAttr={}):
    """
    Reads a list of netCDF attribute definitions from a file into a
    dictionary of lists. This can then be used to set attributes in
    IMOSnetCDF and IMOSnetCDFVariable objects. 

    If an existing dict is passed as a second argument, attributes are
    appended to a copy of it, with newer values overriding anything previously
    set for a given attribute. (The input dict is not modified.)
    """
    
    import re

    F = open(filename)
    lines = re.findall('^\s*(\w*):(.+=.+)', F.read(), re.M)

    attr = inAttr.copy()
    for (var, aSet) in lines:
        if var == '': var = 'global'
        aSet = re.sub(';$', '', aSet)
  
        if attr.has_key(var): attr[var].append(aSet)
        else: attr[var] = [aSet]

    F.close()

    return attr


#############################################################################

# now load the default IMOS attributes
defaultAttributes = attributesFromFile(baseAttributesFile)  
