#! /usr/bin/env python
#

import numpy as np
from IMOSfile.dataUtils import readCSV, timeFromString
import IMOSfile.IMOSnetCDF as inc
from datetime import datetime
import re


# reset default attributes
codeDir = '/home/marty/work/code/BoM/'
BOMattribFile = codeDir+'BoM.attr'
inc.defaultAttributes = inc.attributesFromFile(BOMattribFile)


# csv formats
i = np.int32
# f = np.float64
f = np.float32
form1 = [('Time', 'S24'),
	('Hs',f),
	('Hrms',f),
	('Hmax',f),
	('Tz',f),
	('Ts',f),
	('Tc',f),
	('THmax',f),
	('EPS',f),
	('T02',f),
	('Tp',f),
	('Hrms2',f)]
form2 = form1 + [('EPS2',f)]

# Mapping column headings to variable names
# Trying to follow what Andrew Walsh has done for the MHL Waveriders in NSW.
var = {'Hs':'VAVH',     # sig wave height from the time domain
       'Hrms':'HRMS',   # root mean square wave height from the time domain
       'Hmax':'HMAX',   # maximum wave height in the record - zero upcrossing analysis
       'Tz':'VAVT',     # the zero crossing period from the time domain
       'Ts':'TSIG',     # the period of the significant waves
       'Tc':'TCREST',   # the crest period
       'THmax':'THMAX', # the period of the maximum wave
       'EPS':'EPS',     # spectral width from the time domain
       'T02':'T02',     # the period from spectral moments 0 and 2
       'Tp':'TP1',      # ??? the period at the peak spectral energy
       'Hrms2':'YRMS',  # ??? root mean square wave height calculated from the spectra
       'EPS2':'EPS2'    # spectral width from the spectra ???
       }

# functions

def convertBoM(csvFile):
    """
    Convert a csv wave data file from BOM into netCDF.
    """
    
    # read in csv file
    form = np.dtype(form1)
    data = readCSV(csvFile, form)
    if type(data) <> np.ndarray:
        form = np.dtype(form2)
        data = readCSV(csvFile, form)
      

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch, '%d/%m/%Y %H:%M:%S')
    # correct to UTC ???

    # create netCDF file
    ncFile = csvFile.replace('.csv','') + '.nc'
    attribFile = codeDir + csvFile[:4] + '.attr'
    file = inc.IMOSnetCDFFile(ncFile, attribFile)

    year = re.findall('\d{4}', csvFile)[0]
    file.title += ' in ' + year

    TIME = file.setDimension('TIME', time)
    LAT = file.setDimension('LATITUDE', file.geospatial_lat_min)
    LON = file.setDimension('LONGITUDE', file.geospatial_lon_min)

    for col in form.names[1:]:
        if not var.has_key(col):
            print 'WARNING: Skipping column "' + col + '"!'
            continue
        file.setVariable(var[col], data[col], ('TIME','LATITUDE','LONGITUDE'))


    # set standard filename
    file.updateAttributes()

    file.close()



# run from command line

if __name__=='__main__':
    import sys

    if len(sys.argv)<2: 
        print 'usage:'
        print '  '+sys.argv[0]+' file.csv'
        exit()

    convertBoM(sys.argv[1])
