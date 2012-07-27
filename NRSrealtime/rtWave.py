#! /usr/bin/env python
#
# Python module to process real-time Wave data from ANMN NRS moorings.


import numpy as np
from IMOSfile.dataUtils import readCSV, timeFromString
import IMOSfile.IMOSnetCDF as inc
from datetime import datetime


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

def procWave(station, start_date=None, end_date=None, csvFile='Wave.csv'):
    """
    Read data from a Wave.csv file (in current directory, unless
    otherwise specified) and convert it to a netCDF file (Wave.nc by
    default).
    """

    # load default netCDF attributes for station
    assert station
    attribFile = '/home/marty/work/code/NRSrealtime/'+station+'_Wave.attr'
    
    # read in Wave file
    data = readCSV(csvFile, formWave)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch)

    # select time range
    ii = np.arange(len(dtime))
    if end_date:
        ii = np.where(dtime < end_date)[0]
    if start_date:
        ii = np.where(dtime[ii] >= start_date)[0]
    if len(ii) < 1:
        print csvFile+': No data in given time range!'
        return
    data = data[ii]
    time = time[ii]
    dtime = dtime[ii]

    # create netCDF file
    file = inc.IMOSnetCDFFile(attribFile=attribFile)

    TIME = file.setDimension('TIME', time)
    LAT = file.setDimension('LATITUDE', file.geospatial_lat_min)
    LON = file.setDimension('LONGITUDE', file.geospatial_lon_min)

    VAVH = file.setVariable('VAVH', data['Sig. Wave Height'], ('TIME','LATITUDE','LONGITUDE'))
    # VAVH._FillValue = ???

    # set standard filename
    file.updateAttributes()
    file.standardFileName('W', file.deployment_code+'-wave-height')

    file.close()



### processing - if run from command line

if __name__=='__main__':
    import sys

    if len(sys.argv)<2: 
        print 'usage:'
        print '  '+sys.argv[0]+' station_code [year [input_file.csv] ]'
        exit()

    station = sys.argv[1]

    if len(sys.argv)>2: 
        year = int(sys.argv[2])
        start_date = datetime(year, 1, 1)
        end_date = datetime(year+1, 1, 1)
    else:
        start_date = None
        end_date = None

    csvFile='Wave.csv'
    if len(sys.argv)>3: csvFile = sys.argv[3]
    
    procWave(station, start_date, end_date, csvFile)

