#! /usr/bin/env python
#
# Python module to process real-time WQM from an ANMN National Reference Station.


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
    otherwise specified) and convert it to two netCDF files, one for
    each instrument. The filenames are returned.
    """

    # load default netCDF attributes for station
    assert station
    attribFile = os.getenv('PYTHONPATH') + '/NRSrealtime/'+station+'_WQM.attr'

    # pre-process downloaded csv file
    # (sort chronologically, remove duplicates and incomplete rows)
    ppFile = preProcessCSV(csvFile, nCol=14, sortKey='7')
    if not ppFile:
        print 'WARNING: Failed to pre-process %s.' % csvFile
        print '         Proceeding with original file...'
        ppFile = csvFile

    # read in WQM file
    data = readCSV(ppFile, formWQM)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch)

    # sort chronologically and filter by date range
    (time, dtime, data) = timeSubset(time, dtime, data, start_date, end_date)

    # create two files, one for each WQM instrument
    savedFiles = []

    # nominal depths is not reliable, use pressure to correct
    nominalDepths = set(data['Nominal Depth'])
    pressureTolerance = 10.
    pressureThreshold = max(nominalDepths) - pressureTolerance
    ii = np.where(data['Pressure'] < pressureThreshold)
    data['Nominal Depth'][ii] = min(nominalDepths)
    ii = np.where(data['Pressure'] > pressureThreshold)
    data['Nominal Depth'][ii] = max(nominalDepths)

    for depth in nominalDepths:
        jj = np.where(data['Nominal Depth'] == depth)[0]
        dd = data[jj]
        tt = time[jj]
        dtt = dtime[jj]

        # create netCDF file
        file = inc.IMOSnetCDFFile(attribFile=attribFile)
        file.instrument_serial_number = "see SERIAL_NO variable"
        file.instrument_nominal_depth = depth
        file.instrument_nominal_height = file.site_nominal_depth - depth
        file.geospatial_vertical_min = depth
        file.geospatial_vertical_max = depth

        # dimensions
        TIME = file.setDimension('TIME', tt)
        LAT = file.setDimension('LATITUDE', file.geospatial_lat_min)
        LON = file.setDimension('LONGITUDE', file.geospatial_lon_min)
        #DEPTH = ??? should add this using seawater toolbox!

        # variables
        TEMP = file.setVariable('TEMP', dd['Temperature'], ('TIME','LATITUDE','LONGITUDE'))

        PRES_REL = file.setVariable('PRES_REL', dd['Pressure'], ('TIME','LATITUDE','LONGITUDE'))
        # PRES_REL.applied_offset = -10.1352972  ???

        PSAL = file.setVariable('PSAL', dd['Salinity'], ('TIME','LATITUDE','LONGITUDE'))

        DOX1 = file.setVariable('DOX1', dd['Dissolved Oxygen'], ('TIME','LATITUDE','LONGITUDE'))

        CPHL = file.setVariable('CPHL', dd['Chlorophyll'], ('TIME','LATITUDE','LONGITUDE'))
        
        TURB = file.setVariable('TURB', dd['Turbidity'], ('TIME','LATITUDE','LONGITUDE'))
        
        snFill = -9999
        sn = dd['Serial No']
        bad = (sn<=0).nonzero()
        sn[bad] = snFill
        SERIAL_NO = file.setVariable('SERIAL_NO', sn, ('TIME','LATITUDE','LONGITUDE'), fill_value=snFill)
        SERIAL_NO.long_name = "instrument_serial_number"
        
        VOLT = file.setVariable('VOLT', dd['Voltage'], ('TIME','LATITUDE','LONGITUDE'))


        # plot past 7 days of data
        plotTitle = re.sub('.*from ', '', file.title) + ', %.0fm WQM' % depth
        plotVars = [(TEMP, 'Temperature'),
                    (PRES_REL, 'Relative Pressure'),
                    (PSAL, 'Salinity'),
                    (DOX1, 'Dissolved Oxygen'),
                    (CPHL, 'Chlorophyll'),
                    (TURB, 'Turbidity'),
                    (VOLT, 'Voltage')]
        for var, name in plotVars:
            plotfile = station + ('_%.0fm_' % depth) + name.replace(' ', '') + '.png'
            npl = plotRecent(dtt, var[:,0,0], filename=plotfile, 
                             ylabel=name+' ('+var.units+')', title=plotTitle)
            if npl: print 'Plotted %4d points in %s' % (npl, plotfile)



        # set standard filename
        file.updateAttributes()
        savedFiles.append( 
            file.standardFileName('TPSOBUE', 
                                  file.deployment_code+'-WQM-%.0f' % depth)
            )

        file.close()

    return savedFiles



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

