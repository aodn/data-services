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
from common import upload
from datetime import datetime
import sys, os
import argparse


### default start date for netCDF files #################################

end_date = datetime.now()  # exclude data from the future (bad timestamps)


### parse command line ##################################################

parser = argparse.ArgumentParser()
parser.add_argument('station', help='NRS station code')
parser.add_argument('ftp_dir', help='data source directory on CMAR ftp site')
parser.add_argument('start_date', default=datetime(end_date.year, 1, 1), nargs='?',
                    help='Exclude data before DATE (YYYY-MM-DD or YYYY)')
parser.add_argument('-n', '--nominal_depths', nargs=2, default=None, type=float,
                    help='Nominal depths for WQM', metavar=('D1','D2') )
parser.add_argument('-d', '--data_dir', 
                    help='upload data to DIR', metavar='DIR')
parser.add_argument('-p', '--plots_dir', 
                    help='upload plots to DIR', metavar='DIR')
args = parser.parse_args()

station = args.station
ftp_dir = args.ftp_dir
if isinstance(args.start_date, basestring):
    try:
        start_date = datetime.strptime(args.start_date, '%Y-%m-%d')
    except:
        start_date = datetime(int(args.start_date), 1, 1)
else:
    start_date = args.start_date
nominal_depths = args.nominal_depths
data_dir = args.data_dir
plots_dir = args.plots_dir


### clean up #################################################

cmd = 'rm  *.nc *.csv *.png *.log'
print 'Cleaning up...\n' + cmd
os.system(cmd)



### download latest csv data #################################

wget = 'wget '

opt =  '-o wget.log --recursive --no-directories --quota=200m  '

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
metFile = procPlatform(station, start_date, end_date)
allOK = metFile.find('IMOS') == 0

## Wave height
print '\nWave height...'
waveFile = procWave(station, start_date, end_date)
allOK = allOK and waveFile.find('IMOS') == 0

## WQM
print '\nWQM data....'
WQMFiles = procWQM(station, start_date, end_date, nominal_depths=nominal_depths)
allOK = (allOK and
         WQMFiles[0].find('IMOS') == 0 and
         WQMFiles[1].find('IMOS') == 0)


### upload files ###############################################

uploadLog = 'upload.log'
dataOK = plotsOK = False

if allOK and data_dir:
    print '\nUploading netCDF files to ' + data_dir
    prevMatch = 'IMOS_ANMN-NRS*_' + start_date.strftime('%Y%m%d') + '*'

    metDest =  os.path.join(data_dir, 'Meteorology')
    metOK = upload(metFile, metDest, delete=prevMatch, log=uploadLog)

    waveDest =  os.path.join(data_dir, 'Wave')
    waveOK = upload(waveFile, waveDest, delete=prevMatch, log=uploadLog)

    WQMDest =  os.path.join(data_dir, 'Biogeochem_timeseries')
    WQMOK = (upload(WQMFiles[0], WQMDest, delete=prevMatch, log=uploadLog) and
             upload(WQMFiles[1], WQMDest, log=uploadLog))

    dataOK = metOK and waveOK and WQMOK

if allOK and plots_dir:
    print '\nUploading plots to ' + plots_dir
    plotsOK = upload('*.png', plots_dir, log=uploadLog)


if dataOK and plotsOK: 
    print '\n\n%s: Update successful!' % datetime.now().strftime('%Y-%m-%d %H:%M:%S')
