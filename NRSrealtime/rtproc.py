#! /usr/bin/env python
#
# Python module to process real-time data from ANMN NRS moorings.


import numpy as np
import csv
from datetime import datetime



### functions #######################################################


### module variables ###################################################
i = np.int32
f = np.float64
format =  [('Config ID', i),
           ('Trans ID', i),
           ('Record', i),
           ('Header Index', i),
           ('Serial No', i),
           ('Nominal Depth', f),
           ('Time', 'S24'),
           ('Temperature', f),
           ('Pressure', f),
           ('Salinity', f),
           ('Dissolved Oxygen', f),
           ('Chlorophyll', f),
           ('Turbidity', f),
           ('Voltage', f)]

formWQM = np.dtype(format)



### processing ##########################################################

# read in WQM file
data = readCSV('WQM.csv', formWQM)

# convert time from string to something more numeric


# Filter data and time arrays to the time range we want
# ...


# create netCDF file


# create plots

# WQM - each variable over the pas week & since start of year

# Weather plots (from Platform.csv)

# Wave

