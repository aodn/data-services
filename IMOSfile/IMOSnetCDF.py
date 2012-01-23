#! /usr/bin/env python
#
# Python module to manage IMOS-standard netCDF data files.


import Scientific.IO.NetCDF as nc


class IMOSnetCDFFile(object):
    """
    netCDF file following the IMOS netCDF conventions.

    Based on the IMOS NetCDF User Manual (v1.2) and File Naming
    Convention (v1.3), which can be obtained from
    http://imos.org.au/facility_manuals.html
    """

    def __init__(self, filename):
        """
        Create a new empty file, pre-filling some mandatory global attributes.
        """

        # Open the file
        self._F = nc.NetCDFFile(filename, 'w')

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
        "Create a new variable in the file. Returns a NetCDFVariable object."
        return self._F.createVariable(name, type, dimensions)
        
    def sync(self):
        "Write all buffered data to the disk file."
        self._F.sync()

    flush = sync


    def addAttributes(self, var=None, **attr):
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



# Functionality to be added:

# add attributes and data to an open file (auto-filling as many of the
# attributes as possible)

# check that a given file is written according to the IMOS convention,

# check that the filename meets the convention and matches information
# within the file.

