#! /usr/bin/env python
#
# Python module to process real-time data from ANMN NRS surface moorings.


import numpy as np
from IMOSfile.dataUtils import readCSV, timeFromString, plotRecent
from IMOSfile.dataUtils import timeSubset
import IMOSfile.IMOSnetCDF as inc
from NRSrealtime.common import preProcessCSV
from datetime import datetime
import re, os


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
    attribFile = os.getenv('PYTHONPATH') + '/NRSrealtime/'+station+'_Platform.attr'

    # pre-process downloaded csv file
    # (sort chronologically, remove duplicates and incomplete rows)
    ppFile = preProcessCSV(csvFile, nCol=18, sortKey='5')
    if not ppFile:
        print 'WARNING: Failed to pre-process %s.' % csvFile
        print '         Proceeding with original file...'
        ppFile = csvFile
     
    # read in Platform file
    data = readCSV(ppFile, formPlatform)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch)

    # sort chronologically and filter by date range
    (time, dtime, data) = timeSubset(time, dtime, data, start_date, end_date)

    # create netCDF file
    file = inc.IMOSnetCDFFile(attribFile=attribFile)

    TIME = file.setDimension('TIME', time)
    LAT = file.setDimension('LATITUDE', file.geospatial_lat_min)
    LON = file.setDimension('LONGITUDE', file.geospatial_lon_min)


    WDIRF_AVG = file.setVariable('WDIRF_AVG', data['Wind Direction Average'], ('TIME','LATITUDE','LONGITUDE'))

    WSPD_MIN = file.setVariable('WSPD_MIN', data['Wind Speed Minimum'], ('TIME','LATITUDE','LONGITUDE'))

    WSPD_AVG = file.setVariable('WSPD_AVG', data['Wind Speed Average'], ('TIME','LATITUDE','LONGITUDE'))

    WSPD_MAX = file.setVariable('WSPD_MAX', data['Wind Speed Maximum'], ('TIME','LATITUDE','LONGITUDE'))

    AIRT = file.setVariable('AIRT', data['Air Temperature'], ('TIME','LATITUDE','LONGITUDE'))

    RELH  = file.setVariable('RELH', data['Relative Humidity'], ('TIME','LATITUDE','LONGITUDE'))

    ATMS = file.setVariable('ATMS', data['Air Pressure'], ('TIME','LATITUDE','LONGITUDE'))  # 'air_pressure_at_sea_level'

    RAIN_AMOUNT = file.setVariable('RAIN_AMOUNT', data['Accumulated Rainfall'], ('TIME','LATITUDE','LONGITUDE'))

    SSTI = file.setVariable('SSTI', data['Sea Surface Temperature'], ('TIME','LATITUDE','LONGITUDE'))


    # plot past 7 days of data
    plotTitle = re.sub('.*from ', '', file.title)
    plotVars = [(WDIRF_AVG, 'Wind Direction Average'),
                (WSPD_MIN, 'Wind Speed Minimum'),
                (WSPD_AVG, 'Wind Speed Average'),
                (WSPD_MAX, 'Wind Speed Maximum'),
                (AIRT, 'Air Temperature'),
                (RELH, 'Relative Humidity'),
                (ATMS, 'Air Pressure'),
                (RAIN_AMOUNT, 'Accumulated Rainfall'),
                (SSTI, 'Sea Surface Temperature')]
    for var, name in plotVars:
        plotfile = station + '_' + name.replace(' ', '') + '.png'
        npl = plotRecent(dtime, var[:,0,0], filename=plotfile, 
                         ylabel=name+' ('+var.units+')', title=plotTitle)
        if npl: print 'Plotted %4d points in %s' % (npl, plotfile)


    # set standard filename
    file.updateAttributes()
    savedFile = file.standardFileName('MT', file.deployment_code + '-meteorology')

    file.close()

    return savedFile


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

