#!/usr/bin/python

import os, sys
import urllib2
from multiprocessing import Pool
from string import Template
import numpy as np
from datetime import datetime, timedelta
import ACORNConstants
import logging

def fileParts(f):
    return f.split(ACORNConstants.DELIMITER)

def getDataPath():
    return os.path.join(os.path.dirname(os.sys.argv[0]), "..")

def downloadFileParallelWrapper(args):
    """
    Helper function when using parallel mode downloading as the multiprocessing
    module is a bit lame and has difficulties passing multiple parameters to a
    function
    """
    return downloadFile(*args)

def downloadFile(url, target=None):
    """
    Downloads a file. If a target is not specified, this function can be used
    to decide whether a url is "download-able".
    """
    try:
        if target is not None:
            logging.info("Downloading '%s' -> '%s'" % (url, target))

        u = urllib2.urlopen(url)

        if target is not None:
            f = open(target, 'wb')
            f.write(u.read())
            f.close()

        logging.info("'%s' - OK" % url)
        return True
    except urllib2.HTTPError, e:
        if e.code == 404:
            logging.debug("Could not download '%s', '%s'" % (url, e.code))
        else:
            logging.error("Could not download '%s', '%s'" % (url, e.code))
    except urllib2.URLError, e:
        logging.error("Could not download '%s', '%s'" % (url, e.args))

    return False

def filesForStation(station, timestamp, fileFlags, fileVersion, fileType):
    files =[]
    for ts in getTimstampRangeForCurrent(timestamp):
        fBasename = genFilename(station, ts, fileFlags, fileVersion, fileType)
        f = os.path.join(
            station,
            str(ts.year).zfill(4),
            str(ts.month).zfill(2),
            str(ts.day).zfill(2),
            fBasename
        )
        files.append(f)

    return files

def genFilename(name, timestamp, parameterCode, fileVersion, suffix):
    return "%s%s%s%s%s%s%s%sFV%s%s%s.nc" % (
        ACORNConstants.FACILITY_PREFIX, ACORNConstants.DELIMITER,
        parameterCode, ACORNConstants.DELIMITER,
        timestamp.strftime(ACORNConstants.DATE_TIME_FORMAT), ACORNConstants.DELIMITER,
        name, ACORNConstants.DELIMITER,
        fileVersion, ACORNConstants.DELIMITER, suffix
    )

def generateCurrentFilename(siteName, timestamp, qc=False):
    fileVersion = "00"
    if qc:
        fileVersion = "01"

    return genFilename(siteName, timestamp, "V", fileVersion, "1-hour-avg")

def getFileType(f):
    parts = fileParts(f)
    if len(parts) >= 7:
        return parts[6][:-3]

def isRadial(f):
    return getFileType(f) == "radial"

def isVector(f):
    return getFileType(f) == "sea-state"

def isQc(f):
    return getFileVersion(f) == "FV01"

def daysSince1950(timestamp):
    return (timestamp - datetime.strptime("19500101T000000Z", "%Y%m%dT%H%M%SZ")).total_seconds() / (60 * 60 * 24)

def getFileVersion(f):
    return fileParts(f)[5]

def getTimestamp(f):
    return datetime.strptime(fileParts(f)[3], ACORNConstants.DATE_TIME_FORMAT)

def getStation(f):
    return fileParts(f)[4]

def siteFilename(site, timestamp, qc):
    # For QC mode, sites has the same grid
    if qc:
        return site

    siteDescription = getSiteDescription(site, timestamp)

    fileSuffix = ""
    if 'fileSuffix' in siteDescription:
        fileSuffix = siteDescription['fileSuffix']


    return "%s%s" % (site, fileSuffix)

def getGdopFile(site, timestamp, qc):
    stationType = getSiteDescription(site, timestamp)['type']
    return os.path.join(getDataPath(), stationType, "%s.gdop" % siteFilename(site, timestamp, qc))

def getGridFileCODAR(site, timestamp, qc):
    # Relevant only for CODAR
    stationType = getSiteDescription(site, timestamp)['type']
    return os.path.join(getDataPath(), stationType, "grid_%s.dat" % siteFilename(site, timestamp, qc))

def getLatFileWERA(site, timestamp, qc):
    # Relevant only for WERA
    stationType = getSiteDescription(site, timestamp)['type']
    return os.path.join(getDataPath(), stationType, "LAT_%s.dat" % siteFilename(site, timestamp, qc))

def getLonFileWERA(site, timestamp, qc):
    # Relevant only for WERA
    stationType = getSiteDescription(site, timestamp)['type']
    return os.path.join(getDataPath(), stationType, "LON_%s.dat" % siteFilename(site, timestamp, qc))

def numberToFillValue(d, fillValue=ACORNConstants.FLOAT_FILL_VALUE, number=0):
    d[d==number] = fillValue
    return d

def nanToFillValue(d, fillValue=ACORNConstants.FLOAT_FILL_VALUE):
    d[np.isnan(d)] = fillValue
    return d

def getGdopForSite(site, timestamp, qc, dimension):
    gdop = np.full(dimension, fill_value=np.nan, dtype=np.float)
    i = -1
    with open(getGdopFile(site, timestamp, qc)) as f:
        for line in f.readlines():
            if i > -1: # Skip first line
                gdop[i] = np.float(line.split()[4])
            i += 1
    return gdop


def getGridForSite(site, timestamp, qc):
    stationType = getSiteDescription(site, timestamp)['type']

    if stationType == "WERA":
        return getGridForSiteWERA(site, timestamp, qc)
    elif stationType == "CODAR":
        return getGridForSiteCODAR(site, timestamp, qc)
    else:
        logging.error("Cannot get grid for site '%s', unknown type" % site)
        exit(1)

def getGridForSiteWERA(site, timestamp, qc):
    """
    This returns a hash with arrays corresponding to lon and lat dimensions
    """

    grid = {}
    with open(getLonFileWERA(site, timestamp, qc)) as f:
        lines = f.readlines()
    grid['lon'] = [np.float64(i) for i in lines]

    with open(getLatFileWERA(site, timestamp, qc)) as f:
        lines = f.readlines()
    grid['lat'] = [np.float64(i) for i in lines]

    return grid

def getGridForSiteCODAR(site, timestamp, qc):
    """
    CODAR has one file with all the grid points that are not aligned to U and V
    This function returns a hash with 2 arrays (lon, lat) that are aligned
    """
    grid = {
        "lon": [],
        "lat": []
    }

    with open(getGridFileCODAR(site, timestamp, qc)) as f:
        lines = f.readlines()

    for line in lines:
        grid['lon'].append(np.float64(line.split("\t")[0]))
        grid['lat'].append(np.float64(line.split("\t")[1]))

    return grid

def getSiteForStation(station):
    for site, siteDescription in ACORNConstants.siteDescriptions.iteritems():
        if station in siteDescription['stationsOrder']:
            return site

    return None

def expandArray(posArray, varArray, dim, dtype=np.int):
    """
    Return an expanded array, fitting values from varArray[posArray] and
    filling nans where there are no values. posArray needs to be zero based
    however the radials are not zero based, so fix the array beforehand
    """

    resultArray = np.full(dim, fill_value=np.nan, dtype=dtype)
    try:
        resultArray[posArray] = np.array(varArray)
    except:
        logging.error("Error expanding array, max POS value is '%d', array size is '%d'" % (max(posArray), dim))
        exit(1)

    # This is a non vectorized version, which does the same, left for clarity
    #for i in range(0, len(posArray)):
    #    # posArray will not be 0 based, so make it zero based
    #    resultArray[posArray[i] - 1] = varArray[i]

    return resultArray

def addNetCDFVariable(F, varName, varInfo, attributeTemplating):
    fillValue = False
    if 'fillValue' in varInfo:
        fillValue = varInfo['fillValue']

    newVar = F.createVariable(
        varName, varInfo['dtype'], varInfo['dimensions'],
        zlib=True, complevel=ACORNConstants.NETCDF_COMPRESSION_LEVEL,
        fill_value=fillValue)

    for variableAttribute in varInfo['attributes']:
        # Allow some templating for strings
        variableAttributeValue = variableAttribute[1]
        if isinstance(variableAttributeValue, basestring):
            variableAttributeValue = Template(variableAttribute[1]).substitute(attributeTemplating)

        newVar.setncattr(
            variableAttribute[0],
            variableAttributeValue
        )

    return newVar

def getCurrentTimestamp(timestamp):
    return timestamp.replace(minute=30, second=0, microsecond=0)

def getSiteDescription(site, timestamp):
    siteDescription = ACORNConstants.siteDescriptions[site].copy()

    if 'overrides' in siteDescription:
        for override in siteDescription['overrides']:
            timeStart = datetime.strptime(override['timeStart'], "%Y%m%dT%H%M%S")
            timeEnd = datetime.strptime(override['timeEnd'], "%Y%m%dT%H%M%S")

            if timestamp > timeStart and timestamp <= timeEnd:
                siteDescription.update(override['attributes'])
                
    return siteDescription

def fillGlobalAttributes(F, site, timestamp, qc, attributeTemplating):
    dateTimeFormat = "%Y-%m-%dT%H:%M:%SZ"

    siteDescription = getSiteDescription(site, timestamp)

    stationString = ""
    for station in siteDescription['stationsOrder']:
        stationString += "%s (%s), " % (siteDescription['stations'][station]['name'], station)
    stationString = stationString[:-2]

    siteGrid = getGridForSite(site, timestamp, qc)
    siteLons = siteGrid['lon']
    siteLats = siteGrid['lat']

    # Merge all specific attributes from station/site type (i.e. WERA, CODAR)
    stationType = siteDescription['type']

    attributeTemplating['siteLongName']      = siteDescription['name']
    attributeTemplating['site']              = site
    attributeTemplating['stations']          = stationString
    attributeTemplating['stationType']       = stationType
    attributeTemplating['timeCoverageStart'] = timestamp.strftime(dateTimeFormat)
    attributeTemplating['timeCoverageEnd']   = timestamp.strftime(dateTimeFormat)
    attributeTemplating['stations']          = stationString
    attributeTemplating['dateCreated']       = datetime.utcnow().strftime(dateTimeFormat)

    # Override some attributes with station specific values that are not
    # templated strings
    attributeTemplating['geospatial_lat_min'] = float(min(siteLats))
    attributeTemplating['geospatial_lat_max'] = float(max(siteLats))
    attributeTemplating['geospatial_lon_min'] = float(min(siteLons))
    attributeTemplating['geospatial_lon_max'] = float(max(siteLons))
    attributeTemplating['local_time_zone']    = siteDescription["timezone"]

    for globalAttribute in ACORNConstants.globalAttributes:
        globalAttributeName, globalAttributeValue = globalAttribute

        if globalAttributeName in attributeTemplating:
            globalAttributeValue = attributeTemplating[globalAttributeName]
        elif isinstance(globalAttributeValue, basestring):
            # Allow templating for strings
            globalAttributeValue = Template(globalAttribute[1]).substitute(attributeTemplating)

        if globalAttributeValue is not None:
            F.setncattr(globalAttribute[0], globalAttributeValue)

def httpLink(base, f):
    return os.path.join(ACORNConstants.HTTP_BASE, ACORNConstants.ACORN_BASE, base, f)

def prepareFiles(tmpDir, base, fileList, maxThreads=6):
    files = {}
    for station, stationFiles in fileList.iteritems():
        urls = []
        cachedPaths = []
        for f in stationFiles:
            url = httpLink(base, f)
            cachedPath = os.path.join(tmpDir, os.path.basename(f))
            urls.append((url, cachedPath))
            cachedPaths.append(cachedPath)

        p = Pool(maxThreads)
        cachedPaths = np.array(cachedPaths)
        results = np.array(p.map(downloadFileParallelWrapper, urls))
        files[station] = list(cachedPaths[results])

    return files

def getExistingFiles(base, fileList, maxThreads=6):
    existingFiles = {}
    for station, files in fileList.iteritems():
        urls = []
        for f in files:
            urls.append(httpLink(base, f))

        p = Pool(maxThreads)
        files = np.array(files)
        results = np.array(p.map(downloadFile, urls))
        existingFiles[station] = list(files[results])

    return existingFiles

def getTimstampRangeForCurrent(timestamp):
    """
    Return all possible timestamps to calculate the average hourly from.
    Basically returns a time delta every 5 minutes starting from 0 minutes
    until 55 minutes of the hour.
    """

    timeStart = timestamp.replace(minute=0)
    timeEnd = timeStart + timedelta(hours=1)
    timeRange = []

    timeIter = timeStart
    while (timeIter < timeEnd):
        timeRange.append(timeIter)
        timeIter = timeIter + timedelta(minutes=ACORNConstants.STATION_FREQUENCY_MINUTES)

    return timeRange
