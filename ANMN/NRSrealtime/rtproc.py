#! /usr/bin/env python
#
# Python module to process all real-time data from a National Reference Station.

from rtWave import procWave
from rtPlatform import procPlatform
from rtWQM import procWQM
from datetime import datetime
import sys



### parse command line ##################################################

if len(sys.argv)<2: 
    print 'usage:'
    print '  '+sys.argv[0]+' station_code [year]'
    print '  '+sys.argv[0]+' station_code start-date [end-date]'
    print '     dates in yyyy-mm-dd format'
    exit()

station = sys.argv[1]

start_date = None
end_date = None

if len(sys.argv)>2:
    start = sys.argv[2]
    try:
        start_date = datetime.strptime(start, '%Y-%m-%d')
    except:
        year = int(start)
        start_date = datetime(year, 1, 1)
        end_date = datetime(year+1, 1, 1)

if len(sys.argv)>3:
    end = sys.argv[3]
    try:
        end_date = datetime.strptime(end, '%Y-%m-%d')
    except:
        print 'Bad format for end date!'
    

print 'start:', start_date
print 'end:  ', end_date


### processing ##########################################################

## Weather
procPlatform(station, start_date, end_date)

## Wave height
procWave(station, start_date, end_date)

## WQM
procWQM(station, start_date, end_date)



# create plots

# WQM - each variable over the pas week & since start of year

# Weather plots (from Platform.csv)

# Wave

