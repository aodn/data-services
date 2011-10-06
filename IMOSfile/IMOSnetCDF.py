#! /usr/bin/env python
#
# Python module to manage IMOS-standard netCDF data files.
#
# 2011  Marton Hidas 

import Scientific.IO.NetCDF as nc


class IMOSNetCDFFile(object):
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
        self.f = nc.NetCDFFile(filename, 'w')

        # Create mandatory global attributes
        self.f.project = 'Integrated Marine Observing System (IMOS)'
        self.f.conventions = 'IMOS version 1.2'
        self.f.data_centre = 'eMarine Information Infrastructure (eMII)'
        self.f.data_centre_email = 'info@emii.org.au'

    def close(self):
        "Write all data to the file and close."
        self.f.close()

    def createDimension(self, name, length):
        "Create a new dimension."
        self.f.createDimension(name, length)

    def createVariable(self, name, type, dimensions):
        "Create a new variable in the file. Returns a NetCDFVariable object."
        return self.f.createVariable(name, type, dimensions)

    def sync(self):
        "Write all buffered data to the disk file."
        self.f.sync()

    flush = sync


# Functionality to be added:

# add attributes and data to an open file (auto-filling as many of the
# attributes as possible)

# check that a given file is written according to the IMOS convention,

# check that the filename meets the convention and matches information
# within the file.

