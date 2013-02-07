#! /usr/bin/env python
#
# Python module to process real-time CO2 data from ANMN acidification moorings.


import numpy as np
import os
from IMOSfile.dataUtils import readCSV, timeFromString
import IMOSfile.IMOSnetCDF as inc
from datetime import datetime


### module variables ###################################################

i = np.int32
f = np.float64
formCO2 = np.dtype(
    [('serial_nos', i),
     ('utc_time', 'S24'),
     ('latitude', f),
     ('longitude', f),
     ('xco2_water_raw', f),
     ('xco2_sd_water_raw', f),
     ('xco2_air_raw', f),
     ('xco2_sd_air_raw', f),
     ('sea_surface_temperature', f),
     ('sea_surface_salinity', f)
     ])



### functions #######################################################

def procCO2(station, csvFile, start_date=None, end_date=None):
    """
    Read data from a CSV file (in current directory, unless
    otherwise specified) and convert it to a netCDF file.
    """

    # load default netCDF attributes for station
    assert station
    attribFile = os.getenv('PYTHONPATH') + '/NRSrealtime/'+station+'_CO2.attr'
    inc.defaultAttributes = inc.attributesFromFile(attribFile, inc.defaultAttributes)  

    # read in CO2 file
    data = readCSV(csvFile, formCO2)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['utc_time'], inc.epoch)

    # ensure chronological order
    ii = np.argsort(time, kind='heapsort')
    data = data[ii]
    time = time[ii]
    dtime = dtime[ii]

    # select time range
    i = 0
    j = len(time)
    if start_date:
        while i < j and dtime[i] < start_date:
            i += 1
    if end_date:
        while i < j and dtime[j-1] > end_date: 
            j -= 1
    if i == j: 
        print 'No data in selected date range!'
        exit()
    data = data[i:j]
    time = time[i:j]
    dtime = dtime[i:j]

    # create netCDF file
    file = inc.IMOSnetCDFFile(station+'.nc')
    file.title = 'Raw CO2 data from Kangaroo Island National Reference Station'

    TIME = file.setDimension('TIME', time)
#    LAT = file.setDimension('LATITUDE', )
#    LON = file.setDimension('LONGITUDE', )

    LAT = file.setVariable('LATITUDE', data['latitude'], ('TIME',))
    LON = file.setVariable('LONGITUDE', data['longitude'], ('TIME',))
    XCO2_W = file.setVariable('XCO2_WATER', data['xco2_water_raw'], ('TIME',))
#    XCO2_W.longname = ''
    XCO2_A = file.setVariable('XCO2_AIR', data['xco2_sd_air_raw'], ('TIME',))
#    LAT = file.setVariable('', data[], ('TIME',))

    # set standard filename
    file.updateAttributes()
#    file.standardFileName('W', 'NRSMAI-Surface-wave-height')

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

    csvFile='pco2_mooring_data_KANGAROO_1.csv'
    if len(sys.argv)>3: csvFile = sys.argv[3]
    
    procCO2(station, csvFile, start_date, end_date)

