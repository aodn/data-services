#! /usr/bin/env python
#
# Python module to process real-time Wave data from ANMN NRS moorings.


import numpy as np
from datetime import datetime
from NRSrealtime.quickCSV import readCSV
import IMOSfile.IMOSnetCDF as inc

# load default netCDF attributes
inc.defaultAttributes = inc.attributesFromFile('/home/marty/work/code/NRSrealtime/attributes.txt')  


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

epoch = datetime(1950,1,1)



### functions #######################################################

def timeFromString(timeStr, epoch):
    """
    Convert time from a YYYY-MM-DDThh:mm:ssZ string to two arrays,
    returned as a tuple. The first gives the decimal days from the epoch
    (given as a datetime obect). The second is an array of datetime
    objects.
    """
    dtime = []
    time  = []
    for tstr in timeStr: 
        dt = datetime.strptime(tstr, '%Y-%m-%dT%H:%M:%SZ')
        dtime.append(dt)
        time.append((dt-epoch).total_seconds())

    time = np.array(time) / 3600. / 24.
    dtime = np.array(dtime)

    return (time, dtime)



def procWave(csvFile='Wave.csv', ncFile='Wave.nc'):
    """
    Read data from a Wave.csv file (in current directory, unless
    otherwise specified) and convert it to a netCDF file (Wave.nc by
    default).
    """
    
    # read in Wave file
    data = readCSV(csvFile, formWave)

    # convert time from string to something more numeric
    (time, dtime) = timeFromString(data['Time'], epoch)
    waveh = data['Sig. Wave Height']

    # create netCDF file
    file = inc.IMOSnetCDFFile(ncFile)
    file.title = 'Real-time data from NRSMAI: significant wave height'

    TIME = file.setDimension('TIME', time)
    
    VAVH = file.setVariable('VAVH', waveh, ('TIME',))
    # VAVH._FillValue = ???

    file.close()



### processing - if run from command line

if __name__=='__main__':
    procWave()




