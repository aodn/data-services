#! /usr/bin/env python
#
# Python module to process real-time data from ANMN NRS surface moorings.


import numpy as np
from IMOSfile.dataUtils import readCSV, timeFromString
import IMOSfile.IMOSnetCDF as inc
from datetime import datetime


### module variables ###################################################

i = np.int32
f = np.float64
formPlatform = np.dtype( 
    [('Config ID', i),
     ('Trans ID', i),
     ('Record', i),
     ('Header Index', i),
     ('Time', 'S24'),
     ('27V Battery Bank Voltage', f),
     ('12V Battery Bank Voltage', f),
     ('Wind Direction Average', f),
     ('Wind Speed Minimum', f),
     ('Wind Speed Average', f),
     ('Wind Speed Maximum', f),
     ('Air Temperature', f),
     ('Relative Humidity', f),
     ('Air Pressure', f),
     ('Accumulated Rainfall', f),
     ('Vaisala Supply Voltage', f),
     ('Vaisala Reference Voltage', f),
     ('Sea Surface Temperature', f)
     ])



### functions #######################################################

def procPlatform(station, start_date=None, end_date=None, csvFile='Platform.csv'):
    """
    Read data from a Platform.csv file (in current directory, unless
    otherwise specified) and convert it to a netCDF file (Wave.nc by
    default).
    """

    # load default netCDF attributes for station
    assert station
    attribFile = '/home/marty/work/code/NRSrealtime/'+station+'_attributes.txt'
     
    # read in Platform file
    data = readCSV(csvFile, formPlatform)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch)

    # select time range
    ii = np.arange(len(dtime))
    if end_date:
        ii = np.where(dtime < end_date)
    if start_date:
        ii = np.where(dtime[ii] > start_date)
    assert len(ii[0]) > 0, 'No data in given time range!'
    data = data[ii]
    time = time[ii]
    dtime = dtime[ii]

    # create netCDF file
    file = inc.IMOSnetCDFFile(attribFile=attribFile)
    file.title = 'Real-time weather data from Maria Island National Reference station'
    file.instrument = 'Vaisala WXT510'  # model ???  serial no ???

    TIME = file.setDimension('TIME', time)
    LAT = file.setDimension('LATITUDE', -44.5)
    LON = file.setDimension('LONGITUDE', 143.777)


    WDIR = file.setVariable('WDIR', data['Wind Direction Average'], ('TIME',))

    WSPD_MIN = file.setVariable('WSPD_MIN', data['Wind Speed Minimum'], ('TIME',))

    WSPD_AVG = file.setVariable('WSPD_AVG', data['Wind Speed Average'], ('TIME',))

    WSPD_MAX = file.setVariable('WSPD_MAX', data['Wind Speed Maximum'], ('TIME',))

    AIRT = file.setVariable('AIRT', data['Air Temperature'], ('TIME',))

    RELH  = file.setVariable('RELH', data['Relative Humidity'], ('TIME',))

    ATMS = file.setVariable('ATMS', data['Air Pressure'], ('TIME',))  # 'air_pressure_at_sea_level'

    RAIN_AMOUNT = file.setVariable('RAIN_AMOUNT', data['Accumulated Rainfall'], ('TIME',))

    SST = file.setVariable('SST', data['Sea Surface Temperature'], ('TIME',))

    # set standard filename
    file.updateAttributes()
    file.standardFileName('MT', 'NRSMAI-Surface-realtime-meteorology')

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

    csvFile='Platform.csv'
    if len(sys.argv)>3: csvFile = sys.argv[3]
    
    procPlatform(station, start_date, end_date, csvFile)

