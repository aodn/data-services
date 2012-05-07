#! /usr/bin/env python
#
# Python module to process real-time WQM from an ANMN National Reference Station.


import numpy as np
from IMOSfile.dataUtils import readCSV, timeFromString
import IMOSfile.IMOSnetCDF as inc
from datetime import datetime


### module variables ###################################################

i = np.int32
f = np.float64
formWQM = np.dtype(
    [('Config ID', i),
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
     ('Voltage', f)
     ])



### functions #######################################################

def procWQM(station, start_date=None, end_date=None, csvFile='WQM.csv'):
    """
    Read data from a WQM.csv file (in current directory, unless
    otherwise specified) and convert it to a netCDF file (Wave.nc by
    default).
    """

    # load default netCDF attributes for station
    assert station
    attribFile = '/home/marty/work/code/NRSrealtime/'+station+'_attributes.txt'
     
    # read in WQM file
    data = readCSV(csvFile, formWQM)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch)

    # select time range
    ii = np.arange(len(dtime))
    if end_date:
        ii = np.where(dtime < end_date)
    if start_date:
        ii = np.where(dtime[ii] > start_date)
    if len(ii[0]) < 1:
        print csvFile+': No data in given time range!'
        return
    data = data[ii]
    time = time[ii]
    dtime = dtime[ii]

    # create two files, one for each WQM instrument
    for depth in set(data['Nominal Depth']):
        jj = np.where(data['Nominal Depth'] == depth)
        dd = data[jj]
        tt = time[jj]

        # create netCDF file
        file = inc.IMOSnetCDFFile(attribFile=attribFile)
        file.title = 'Real-time WQM data from Maria Island National Reference station'
        file.instrument = 'Wetlabs WQM'  # model ???  serial no ???

        TIME = file.setDimension('TIME', tt)
        LAT = file.setDimension('LATITUDE', -44.5)
        LON = file.setDimension('LONGITUDE', 143.777)


        WDIR = file.setVariable('WDIR', dd['Wind Direction Average'], ('TIME',))


        # set standard filename
        file.updateAttributes()
        file.standardFileName('', 'NRSMAI-SubSurface-realtime-WQM-%f.0' % depth)

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

    csvFile='WQM.csv'
    if len(sys.argv)>3: csvFile = sys.argv[3]
    
    procWQM(station, start_date, end_date, csvFile)

