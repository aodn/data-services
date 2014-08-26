#! /usr/bin/env python
#
# Python module to manage IMOS-standard netCDF data files.


import numpy as np
from datetime import datetime, timedelta
import os, re, time
from collections import OrderedDict


# The idea is to create a set of functions that make it easier to
# create netCDF files meeting the IMOS convetions. Where possible,
# these functions should work with netCDF file & variable objects from
# any module (netCDF4, scipy.io.netcdf, Scientific.IO.NetCDF) as long
# as they implement the same API.

# Functions to implement

# add attributes (global and variable), given as arguments or read
# from a file
def addAttributes(ncFile, attrib):


# add a variable (data and metadata, including mandatory attributes)

# add a dimension variable (data and metadata, including mandatory attributes)

# calculate & add global attributes such as spatial/temporal coverage

# close the file, renaming it to the standard IMOS filename

