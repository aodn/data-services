#! /usr/bin/env python
#
# Python module to process real-time Wave data from ANMN NRS moorings.


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
    attribFile = os.getenv('PYTHONPATH') + '/NRSrealtime/'+station+'_Wave.attr'
    
    # pre-process downloaded csv file
    # (sort chronologically, remove duplicates and incomplete rows)
    ppFile = preProcessCSV(csvFile, nCol=6, sortKey='5')
    if not ppFile:
        print 'WARNING: Failed to pre-process %s.' % csvFile
        print '         Proceeding with original file...'
        ppFile = csvFile

    # read in Wave file
    data = readCSV(ppFile, formWave)

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

    VAVH = file.setVariable('VAVH', data['Sig. Wave Height'], ('TIME','LATITUDE','LONGITUDE'))
    # VAVH._FillValue = ???


    # title for plots
    plot_title = re.sub('.*from ', '', file.title)

    # plot past 7 days of data
    plotfile = station+'_SignificantWaveHeight.png'
    npl = plotRecent(dtime, VAVH[:,0,0], filename=plotfile, 
                     ylabel='Significant Wave Height ('+VAVH.units+')', title=plot_title)
    if npl: print 'Plotted %4d points in %s' % (npl, plotfile)


    # set standard filename
    file.updateAttributes()
    savedFile = file.standardFileName('W', file.deployment_code+'-wave-height')

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

    csvFile='Wave.csv'
    if len(sys.argv)>3: csvFile = sys.argv[3]
    
    procWave(station, start_date, end_date, csvFile)

