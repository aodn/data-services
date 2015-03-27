#! /usr/bin/env python
#
# Python module to process real-time CO2 data from ANMN acidification moorings.


import numpy as np
import os
import sys
from datetime import datetime
from collections import OrderedDict
from IMOSfile.dataUtils import readCSV, timeFromString, timeSortAndSubset
import IMOSfile.IMOSnetCDF as inc


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
    If successful, the name of the saved file is returned.
    """

    # pre-process CSV file to change 'None' values to the fill value
    # used in the netCDF file for these variables
    p, f = os.path.split(csvFile)
    ppFile = 'pp_'+f
    cmd = "sed 's/None/%.1f/g' %s >%s" % (inc.defaultAttributes['SSTI']['_FillValue'],
                                          csvFile, ppFile)

    if os.system(cmd) != 0:
        print >>sys.stderr,  'Failed to pre-process %s!\n' % csvFile

    # read in CO2 file
    data = readCSV(ppFile, formCO2)

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['utc_time'], inc.epoch)

    # sort chronologically and filter by date range
    (time, dtime, data) = timeSortAndSubset(time, dtime, data, start_date, end_date)

    # create netCDF file (including default netCDF attributes for station)
    attribFile = os.getenv('PYTHONPATH') + '/AM/'+station+'_CO2.attr'
    file = inc.IMOSnetCDFFile(attribFile=attribFile)

    # attributes for standard deviation variables
    for var in ['XCO2_WATER', 'XCO2_AIR']:
        vAttr = file.attributes[var]
        vAttr['ancillary_variables'] = var + '_standard_deviation'
        sdAttr = OrderedDict()
        sdAttr['long_name'] = vAttr['long_name'] + ' standard_deviation'
        sdAttr['units'] = vAttr['units']
        sdAttr['_FillValue'] = vAttr['_FillValue']
        file.attributes[vAttr['ancillary_variables']] = sdAttr

    # add dimension and variables
    TIME = file.setDimension('TIME', time)

    LAT = file.setVariable('LATITUDE', data['latitude'], ('TIME',))
    LON = file.setVariable('LONGITUDE', data['longitude'], ('TIME',))

    XCO2_WATER = file.setVariable('XCO2_WATER', data['xco2_water_raw'], ('TIME',))
    XCO2_WATER_sd = file.setVariable('XCO2_WATER_standard_deviation', data['xco2_sd_water_raw'], ('TIME',))

    XCO2_AIR = file.setVariable('XCO2_AIR', data['xco2_air_raw'], ('TIME',))
    XCO2_AIR_sd = file.setVariable('XCO2_AIR_standard_deviation', data['xco2_sd_air_raw'], ('TIME',))

    SSTI = file.setVariable('SSTI', data['sea_surface_temperature'], ('TIME',))
    SSS = file.setVariable('SSS', data['sea_surface_salinity'], ('TIME',))

    # set standard filename
    file.deployment_code = file.platform_code + dtime[0].strftime('-%y%m')
    file.updateAttributes()
    try:
        ncFile = file.standardFileName('KST', file.deployment_code+'-realtime-raw')
    except:
        ncFile = None

    file.close()

    return ncFile


### processing - if run from command line

if __name__=='__main__':
    import argparse

    # parse command line
    parser = argparse.ArgumentParser()
    parser.add_argument('csvFile', help='csv input file')
    args = parser.parse_args()
    csvFile = args.csvFile

    # stop here if csv file has not changed
    localCsvFile = os.path.basename(csvFile)
    if (os.path.isfile(localCsvFile) and os.system('diff %s %s >/dev/null' % (localCsvFile, csvFile)) == 0):
        print >>sys.stderr,  '\n\n%s: %s has not changed.' % (
            datetime.now().strftime('%Y-%m-%d %H:%M:%S'), csvFile)
        exit(0)

    # work out which station we're looking at
    if csvFile.find('KANGAROO') >= 0:
        station = 'NRSKAI'
    elif csvFile.find('MARIA') >= 0:
        station = 'NRSMAI'
    elif csvFile.find('YONGALA') >= 0:
        station = 'NRSYON'
    else:
        print >>sys.stderr,  "Can't determine station from input file name."
        exit(1)

    # create the netCDF file and print its name if successful
    ncFile = procCO2(station, csvFile)
    if not ncFile:
        print >>sys.stderr,  '\n\n%s: Failed to create netCDF file!' % datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        exit(1)
    print >>sys.stdout, ncFile

    # save a copy of the csvFile in local directory
    if os.system('rsync -pt %s ./' % csvFile) != 0:
        print >>sys.stderr,  '\n\n%s: Failed to rsync %s to local directory!' % (
            datetime.now().strftime('%Y-%m-%d %H:%M:%S'), csvFile)

    print >>sys.stderr,  '\n\n%s: Update successful!' % datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    exit(0)
