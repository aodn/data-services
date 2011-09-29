#! /usr/bin/env python
#
# Python module to manage IMOS-standard netCDF data files.
#
# 2011  Marton Hidas 

import Scientific.IO.NetCDF as nc


class IMOSNetCDFFile(nc.NetCDFFile):
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
        nc.NetCDFFile.__init__(self, filename, 'w')

        # Create mandatory global attributes
        self.project = 'Integrated Marine Observing System (IMOS)'
        self.conventions = 'IMOS version 1.2'
        self.data_centre = 'eMarine Information Infrastructure (eMII)'
        self.data_centre_email = 'info@emii.org.au'


# Functionality to be added:

# add attributes and data to an open file (auto-filling as many of the
# attributes as possible)

# check that a given file is written according to the IMOS convention,

# check that the filename meets the convention and matches information
# within the file.

