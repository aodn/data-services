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
    attribFile = '/home/marty/work/code/NRSrealtime/'+station+'_WQM_attr.txt'
     
    # read in WQM file
    data = readCSV(csvFile, formWQM)

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

    # create two files, one for each WQM instrument
    for depth in set(data['Nominal Depth']):
        jj = np.where(data['Nominal Depth'] == depth)[0]
        dd = data[jj]
        tt = time[jj]

        # create netCDF file
        file = inc.IMOSnetCDFFile(attribFile=attribFile)
        file.instrument_serial_number = "see SERIAL_NO variable"
        file.instrument_nominal_depth = depth
        file.instrument_nominal_height = file.site_nominal_depth - depth

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
        CPHL.comment = "Artificial chlorophyll data computed from bio-optical sensor raw counts using standard WET Labs calibration."
        # CPHL.comment = "Artificial chlorophyll data computed from bio-optical sensor raw counts measurements. Originally expressed in ug/l, 1l = 0.001m3 was assumed."   same as in delayed-mode file ???

        TURB = file.setVariable('TURB', dd['Turbidity'], ('TIME','LATITUDE','LONGITUDE'))
        
        snFill = -9999
        sn = dd['Serial No']
        bad = (sn<=0).nonzero()
        sn[bad] = snFill
        SERIAL_NO = file.setVariable('SERIAL_NO', sn, ('TIME','LATITUDE','LONGITUDE'))
        SERIAL_NO.long_name = "instrument_serial_number"
        SERIAL_NO._FillValue = snFill
        
        # VOLT = file.setVariable('VOLT', dd['Voltage'], ('TIME','LATITUDE','LONGITUDE')) do we need this???


        # set standard filename
        file.updateAttributes()
        file.standardFileName('TPSOBU', 'NRSMAI-SubSurface-realtime-WQM-%.0f' % depth)

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

