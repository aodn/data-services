#/usr/bin/env python

import getopt
import sys

from netCDF4 import Dataset, date2num, num2date


def convertTimeCftoImos(netcdfFilePath):
    """
    convert a CF time into an IMOS one forced to be 'days since 1950-01-01 00:00:00'
    the variable HAS to be 'TIME'
    """

    netcdfFileObj = Dataset(netcdfFilePath, 'a', format='NETCDF4')
    time          = netcdfFileObj.variables['TIME']
    time.calendar = 'gregorian'
    dtime         = num2date(time[:], time.units, time.calendar)   # this gives an array of datetime objects
    time.units    = 'days since 1950-01-01 00:00:00 UTC'
    time[:]       = date2num(dtime, time.units, time.calendar) # conversion to IMOS recommended time
    netcdfFileObj.close()


if __name__== "__main__":
    convertTimeCftoImos(str(sys.argv[1:])[2:-2])
