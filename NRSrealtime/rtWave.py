#! /usr/bin/env python
#
# Python module to process real-time Wave data from ANMN NRS moorings.


import numpy as np
from IMOSfile.dataUtils import readCSV, timeFromString
import IMOSfile.IMOSnetCDF as inc


### module variables ###################################################

i = np.int32
f = np.float64
formWave = np.dtype( 
    [('Config ID', i),
     ('Trans ID', i),
     ('Record', i),
     ('Header Index', i),
     ('Time', 'S24'),
     ('Sig. Wave Height', f)])



### functions #######################################################

def procWave(station, csvFile='Wave.csv', ncFile='Wave.nc'):
    """
    Read data from a Wave.csv file (in current directory, unless
    otherwise specified) and convert it to a netCDF file (Wave.nc by
    default).
    """

    # load default netCDF attributes for station
    assert station
    attribFile = '/home/marty/work/code/NRSrealtime/'+station+'_attributes.txt'
    inc.defaultAttributes = inc.attributesFromFile(attribFile, inc.defaultAttributes)  

    
    # read in Wave file
    data = readCSV(csvFile, formWave)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch)
    waveh = data['Sig. Wave Height']

    # create netCDF file
    file = inc.IMOSnetCDFFile(ncFile)
    file.title = 'Real-time data from NRSMAI: significant wave height'

    TIME = file.setDimension('TIME', time)
    LAT = file.setDimension('LATITUDE', -44.5)
    LON = file.setDimension('LONGITUDE', 143.777)

    VAVH = file.setVariable('VAVH', waveh, ('TIME',))
    # VAVH._FillValue = ???

    file.close()



### processing - if run from command line

if __name__=='__main__':
    import sys

    if len(sys.argv)<2: 
        print 'usage:\n  rtWave station_code [input_file.csv]'
        exit()

    station = sys.argv[1]

    csvFile='Wave.csv'
    if len(sys.argv)>2: csvFile = sys.argv[2]
    
    procWave(station, csvFile)

