#! /usr/bin/env python
#
# Python module to process all real-time data from a National Reference Station.

from rtWave import procWave
from rtPlatform import procPlatform
from datetime import datetime
import sys



### parse command line ##################################################

if len(sys.argv)<2: 
    print 'usage:'
    print '  '+sys.argv[0]+' station_code [year]'
    exit()

station = sys.argv[1]

if len(sys.argv)>2: 
    year = int(sys.argv[2])
    start_date = datetime(year, 1, 1)
    end_date = datetime(year+1, 1, 1)
else:
    start_date = None
    end_date = None

    

### processing ##########################################################

## Weather
procPlatform(station, start_date, end_date)

## Wave height
procWave(station, start_date, end_date)

## WQM




# create plots

# WQM - each variable over the pas week & since start of year

# Weather plots (from Platform.csv)

# Wave

