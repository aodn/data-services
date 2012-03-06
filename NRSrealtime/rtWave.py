#! /usr/bin/env python
#
# Python module to process real-time Wave data from ANMN NRS moorings.


import numpy as np
from datetime import datetime
from quickCSV import readCSV
import IMOSfile.IMOSnetCDF as inc


### functions #######################################################



### module variables ###################################################
i = np.int32
f = np.float64
format =  [('Config ID', i),
           ('Trans ID', i),
           ('Record', i),
           ('Header Index', i),
           ('Time', 'S24'),
#           ('WaveHt', f)]
           ('Sig. Wave Height', f)]
formWave = np.dtype(format)

csvFile = 'Wave.csv'
ncFile = 'Wave.nc'


### processing ##########################################################

# read in Wave file
data = readCSV(csvFile, formWave)

# convert time from string to something more numeric
epoch = datetime(1950,1,1)
dtime = []
time  = []
for tstr in data['Time']: 
    dt = datetime.strptime(tstr, '%Y-%m-%dT%H:%M:%SZ')
    dtime.append(dt)
    time.append((dt-epoch).total_seconds())

time = np.array(time) / 3600. / 24.
dtime = np.array(dtime)
waveh = data['Sig. Wave Height']


# Filter data and time arrays to the time range we want
# ...


# create netCDF file
inc.defaultAttributes = inc.attributesFromFile('/home/marty/work/code/NRSrealtime/attributes.txt')  # load default attributes
file = inc.IMOSnetCDFFile(ncFile)
file.title = 'Real-time data from NRSMAI: significant wave height'

TIME = file.setDimension('TIME', time)

VAVH = file.setVariable('VAVH', waveh, ('TIME',))
VAVH.standard_name = 'sea_surface_wave_significant_height'
VAVH.long_name = 'sea_surface_wave_significant_height'
VAVH.units = 'metres'
VAVH.valid_min = 0
VAVH.valid_max = 900
#VAVH._FillValue = ???


file.close()


# create plots
