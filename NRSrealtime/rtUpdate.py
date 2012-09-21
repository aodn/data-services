#! /usr/bin/env python
#
# Update all real-time data streams from a National Reference Station.
# This includes
# * downloading latest csv files from the CMAR ftp site,
# * creating netCDF files for the recent data,
# * creating plots of each variable over the past week,
# * uploading all files to the Data Fabric.

from rtWave import procWave
from rtPlatform import procPlatform
from rtWQM import procWQM
from datetime import datetime
import sys, os


### default start date for netCDF files #################################

start_date = datetime(2012,7,1)


### parse command line ##################################################

if len(sys.argv)<3: 
    print 'usage:'
    print '  '+sys.argv[0]+' station_code ftp_dir'
    exit()

station = sys.argv[1]
ftp_dir = sys.argv[2]


### clean up #################################################

saveDir = './oldfiles'
saveFiles = '*.nc *.csv *.png '
if not os.path.isdir(saveDir):
    os.mkdir(saveDir)
cmd = 'mv ' + saveFiles + saveDir
print 'Cleaning up...\n' + cmd
if os.system(cmd):
    print 'Failed to save old files!\n'
    exit(1)
   

### download latest csv data #################################

wget = 'wget '

opt =  '-o wget.log --recursive --no-directories --quota=100m  '

url='ftp://ftp.marine.csiro.au/pub/IMOS/NRS/' + ftp_dir

cmd = wget + opt + url

print '\nGetting data from CSIRO ftp site...\n' + cmd
if os.system(cmd) <> 0:
    print 'Failed to download data!\n'
    exit(1)



### create netCDF files and plots #############################

print '\nCreating netCDF files and plots...'

## Weather
print '\nMeteorology...'
procPlatform(station, start_date)

## Wave height
print '\nWave height...'
procWave(station, start_date)

## WQM
print '\nWQM data....'
procWQM(station, start_date)



### upload files to the Data Fabric ############################

