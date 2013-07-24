#! /usr/bin/env python
#
# Get latest SOFS files from BOM ftp site and sort them into the
# appropriate directories on opendap.


from IMOSfile.IMOSfilename import parseFilename
import re
from datetime import datetime
import os
import argparse


def dataCategory(info):
    """
    Return the appropriate data category for a file with the given
    attributes (info as returned by parseFilename()).
    """

    if info['data_code'] == 'CMST':
        return 'Surface_properties'

    if info['data_code'] == 'FMT':
        return 'Surface_fluxes'

    if info['data_code'] == 'W':
        return 'Surface_waves'

    if info['data_code'] == 'V':
        return 'Sub-surface_currents'

    if info['data_code'] in ['PT', 'CPT']:
        return 'Sub-surface_temperature_pressure_conductivity'

    return '???'
    

def destPath(info, basePath=''):
    """
    Return the pubplic directory path for a file with the given info
    (as returned by parseFilename()).
    """
    from os.path import join

    if not info.has_key('data_category'):
        info['data_category'] = dataCategory(info)

    if info['data_category'] == '???':
        return ''

    path = join(basePath, info['data_category'])
    
    if type(info['end_time']) is datetime:
        # whole-deployment delayed-mode file, no further sub-directories
        return path

    if info['product_code'] != '1-min-avg':
        # i.e. not a daily delayed-mode product
        path = join(path, 'Real-time')

    path = join(path, info['start_time'].strftime('%Y') + '_daily' )

    return path


def updateFile(source, dest, log=None):
    """
    Synchronise source (file) to dest path, copying the file only if
    it doesn't exist at dest or has been modified more recently than
    the version at dest. Return the number of files updated at dest.
    If log is set to an open file object, log the sync command to it.
    """
    syncCmd = 'rsync -uvt'
    cmd = ' '.join([syncCmd, source, dest])
    if log: 
        print >> log, cmd

    result = os.popen(cmd).readlines()
    if source.find(result[0].strip()) >= 0:
        return 1
    else:
        return 0


### MAIN ###

parser = argparse.ArgumentParser()
parser.add_argument('tmp_dir', help='working directory for downloaded files')
parser.add_argument('target_dir', help='base directory to sort files into')
args = parser.parse_args()


# download new data into tmp_dir using lftp



# set up for iteration through all files
sourceFiles = []
updatedFiles = []
existingFiles = []
skippedFiles = []
LOG = open('sync.log')

print 'sorting files...'
for curDir, dirs, files in os.walk(args.tmp_dir):
    print curDir

    for fileName in files:
        sourcePath = os.join(curDir, fileName)
        sourceFiles.append(sourcePath)

        # try to parse filename
        info, err = parseFilename(fileName, minFields=6)

        # if not netcdf file, skip with warning
        if info['extension'] != 'nc':
            print 'WARNING! Non-netCDF file:', fileName
            skippedFiles.append(sourcePath)
            continue

        # work out destination 
        destinationPath = destPath(info, basePath=args.target_dir)
        if not destinationPath:
            print 'WARNING! Unknown destination for', fileName
            skippedFiles.append(sourcePath)
            continue

        # synch file to its destination (only copy if file is new)
        if updateFile(sourcePath, destinationPath, LOG):
            updatedFiles.append(sourcePath)
        else:
            existingFiles.append(sourcePath)


print '%5d files processed' % len(sourceFiles)
print '%5d files updated' % len(updatedFiles)
print '%5d files already at destination' % len(existingFiles)
print '%5d files skipped' % len(skippedFiles)

print >> LOG, '\nUpdated:\n' + '\n'.join(updatedFiles)
print >> LOG, '\nExisting:\n' + '\n'.join(existingFiles)
print >> LOG, '\nSkipped:\n' + '\n'.join(skippedFiles)

LOG.close()
