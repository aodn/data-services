#!/usr/bin/python

import os, sys
import numpy as np
import tempfile
import shutil
from netCDF4 import Dataset
import logging
import warnings

import ACORNConstants
import ACORNUtils
import ACORNQC

class Util:
    @staticmethod
    def cosDegree(angle):
        return np.cos(np.radians(angle))

    @staticmethod
    def sinDegree(angle):
        return np.sin(np.radians(angle))

    @staticmethod
    def calcUVector(station1MeanSpeed, station1MeanDir, station2MeanSpeed, station2MeanDir):
        return (station1MeanSpeed * Util.cosDegree(station2MeanDir) - station2MeanSpeed * Util.cosDegree(station1MeanDir)) \
            / Util.sinDegree(station1MeanDir - station2MeanDir)

    @staticmethod
    def calcVVector(station1MeanSpeed, station1MeanDir, station2MeanSpeed, station2MeanDir):
        return (station2MeanSpeed * Util.sinDegree(station1MeanDir) - station1MeanSpeed * Util.sinDegree(station2MeanDir)) \
            / Util.sinDegree(station1MeanDir - station2MeanDir)

    @staticmethod
    def calculateUError(station1MeanError, station1MeanDir, station2MeanError, station2MeanDir):
        return np.sqrt((station2MeanError ** 2 * Util.cosDegree(station1MeanDir) ** 2 + station1MeanError ** 2 * Util.cosDegree(station2MeanDir) ** 2) \
            / Util.sinDegree(station1MeanDir - station2MeanDir) ** 2)

    @staticmethod
    def calculateVError(station1MeanError, station1MeanDir, station2MeanError, station2MeanDir):
        return np.sqrt((station2MeanError ** 2 * Util.sinDegree(station1MeanDir) ** 2 + station1MeanError ** 2 * Util.sinDegree(station2MeanDir) ** 2) \
            / Util.sinDegree(station1MeanDir - station2MeanDir) ** 2)

    @staticmethod
    def meanError(error):
        tmpError = np.array(error) # Copy array, so we don't overwrite it

        iNan = np.isnan(tmpError)
        iAllNan = np.all(iNan, axis=0)

        errorCount = np.sum(-iNan, axis=0, dtype=np.float32)
        errorCount[iAllNan] = np.nan # Avoid division by zero, set to nan

        return np.sqrt(np.nansum(np.power(tmpError, 2), axis=0) / errorCount)

    @staticmethod
    def hasEnoughRadials(radialFileList):
        # Return True if each station has at least 3 radials
        retval = True
        for station, radialFiles in radialFileList.iteritems():
            logging.debug( "Station '%s' has '%d' radials available" % (station, len(radialFiles)))
            if len(radialFiles) < ACORNConstants.WERA_MIN_RADIALS_PER_STATION:
                retval = False
                logging.warning("Not enough radials for station '%s', has '%d' but need at least '%d'" % (station, len(radialFiles), ACORNConstants.WERA_MIN_RADIALS_PER_STATION))

        return retval

    @staticmethod
    def getRadialBase(isQC=False):
        if isQC:
            return ACORNConstants.RADIAL_QC_BASE
        else:
            return ACORNConstants.RADIAL_BASE

    @staticmethod
    def getExistingRadials(radialFileList, qc=False):
        return ACORNUtils.getExistingFiles(Util.getRadialBase(qc), radialFileList)

    @staticmethod
    def prepareRadials(tmpDir, radialFileList, qc=False):
        return ACORNUtils.prepareFiles(tmpDir, Util.getRadialBase(qc), radialFileList)

    @staticmethod
    def getRadialsForSite(site, timestamp, qc=False):
        fileVersion = "00"
        if qc:
            fileVersion = "01"

        radials = {}
        siteDescription = ACORNUtils.getSiteDescription(site, timestamp)
        for station in siteDescription['stationsOrder']:
            radials[station] = ACORNUtils.filesForStation(station, timestamp, "RV", fileVersion, "radial")
        return radials

    @staticmethod
    def combineRadials(F, site, timestamp, radialFileList, qc=False):
        maxSpeed = ACORNUtils.getSiteDescription(site, timestamp)['maxSpeed']

        siteGrid = ACORNUtils.getGridForSite(site, timestamp, qc)
        siteLons = siteGrid['lon']
        siteLats = siteGrid['lat']
        latDim = len(siteLats)
        lonDim = len(siteLons)

        if qc:
            logging.info("Using WERA QC")
            attributeTemplating = ACORNConstants.attributeTemplatingWERAQc
        else:
            logging.info("Using WERA non-QC")
            attributeTemplating = ACORNConstants.attributeTemplatingWERA

        siteGdop = ACORNUtils.getGdopForSite(site, timestamp, qc, lonDim * latDim).reshape(lonDim, latDim)

        # Do not pre fill with fill values this dataset, we do it ourselves
        F.set_fill_off()

        stationData = {}

        for station, radialFiles in radialFileList.iteritems():
            radialCount = len(radialFiles)
            logging.info("Averaging '%d' radials for station '%s'" % (radialCount, station))

            stationData[station] = {}

            for var, dtype in ACORNConstants.varMappingWera.iteritems():
                stationData[station][var] = np.full((len(radialFiles), lonDim, latDim), np.nan, dtype=dtype)

            i = 0
            for radial in radialFiles:
                logging.debug("Extracting variables from '%s'" % radial)
                ds = Dataset(radial, mode='r')

                # Make POSITION a zero based (it starts from 1)
                posArray = np.array(ds.variables['POSITION'])
                posArray = posArray - 1

                for var, dtype in ACORNConstants.varMappingWera.iteritems():
                    tmpArray = ACORNUtils.expandArray(
                        posArray, ds.variables[var], lonDim * latDim, dtype)

                    stationData[station][var][i] = tmpArray.reshape((lonDim, latDim))

                ds.close()
                i = i + 1

        ACORNUtils.fillGlobalAttributes(F, site, timestamp, qc, attributeTemplating)

        ACORNQC.enforceSpeedLimit(stationData, "ssr_Surface_Radial_Sea_Water_Speed", maxSpeed)

        ACORNQC.enforceSignalToNoiseRatio(
            stationData,
            "ssr_Bragg_Signal_To_Noise",
            "ssr_Surface_Radial_Sea_Water_Speed_quality_control",
            qc
        )

        ACORNQC.discardQcRange(
            stationData,
            "ssr_Surface_Radial_Sea_Water_Speed_quality_control",
            qc
        )

        ACORNQC.removeLowObservationCount(
            stationData,
            "ssr_Surface_Radial_Sea_Water_Speed"
        )

        ACORNQC.gdopMasking(
            stationData,
            siteGdop,
            "ssr_Surface_Radial_Sea_Water_Speed_quality_control",
            qc
        )

        speedQcMax = np.zeros((lonDim, latDim))

        for station in stationData.keys():
            stationData[station]["observation_count"] = np.sum(np.isfinite(stationData[station]["ssr_Surface_Radial_Sea_Water_Speed"]), axis=0)

            # Calculate mean of speed and direction variable over all stations
            # nanmean returns warning for empty slices, just suppress this as
            # this is the most elegant way to get rid of it:
            # http://stackoverflow.com/questions/29688168/mean-nanmean-and-warning-mean-of-empty-slice
            with warnings.catch_warnings():
                warnings.filterwarnings("ignore", "Mean of empty slice")
                stationData[station]["speed_mean"] = np.nanmean(stationData[station]["ssr_Surface_Radial_Sea_Water_Speed"], axis=0)
                stationData[station]["dir_mean"] = np.nanmean(stationData[station]["ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity"], axis=0)
                stationData[station]["bragg_mean"] = np.nanmean(stationData[station]["ssr_Bragg_Signal_To_Noise"], axis=0)

            # Take the highest QC value for every point
            tmpSpeedQcMax = np.amax(stationData[station]["ssr_Surface_Radial_Sea_Water_Speed_quality_control"], axis=0)
            speedQcMax = np.maximum(
                speedQcMax,
                tmpSpeedQcMax
            )

            stationData[station]["error_mean"] = Util.meanError(stationData[station]["ssr_Surface_Radial_Sea_Water_Speed_Standard_Error"])

        station1 = ACORNUtils.getSiteDescription(site, timestamp)['stationsOrder'][0]
        station2 = ACORNUtils.getSiteDescription(site, timestamp)['stationsOrder'][1]

        # If there is no speed measurement in a point, set the QC flag to nan
        speedQcMax[np.isnan(stationData[station1]["speed_mean"])] = np.nan
        speedQcMax[np.isnan(stationData[station2]["speed_mean"])] = np.nan

        # Combine speed to get U and V
        UCUR = Util.calcUVector(
            stationData[station1]["speed_mean"], stationData[station1]["dir_mean"],
            stationData[station2]["speed_mean"], stationData[station2]["dir_mean"]
        )

        VCUR = Util.calcVVector(
            stationData[station1]["speed_mean"], stationData[station1]["dir_mean"],
            stationData[station2]["speed_mean"], stationData[station2]["dir_mean"]
        )

        UCUR_sd = Util.calculateUError(
            stationData[station1]["error_mean"], stationData[station1]["dir_mean"],
            stationData[station2]["error_mean"], stationData[station2]["dir_mean"]
        )

        VCUR_sd = Util.calculateVError(
            stationData[station1]["error_mean"], stationData[station1]["dir_mean"],
            stationData[station2]["error_mean"], stationData[station2]["dir_mean"]
        )

        # Enforce speed limit on U and V, if qc=1 or qc=2
        uSpeedExceeded = ACORNQC.getExceededSpeedLimit(UCUR, maxSpeed)
        logging.debug("Setting QC=3 on '%d' U values which exceeded speed limit of '%f'" % (np.sum(uSpeedExceeded), maxSpeed))
        speedQcMax[uSpeedExceeded & ((speedQcMax == 1) | (speedQcMax == 2))] = 3

        vSpeedExceeded = ACORNQC.getExceededSpeedLimit(VCUR, maxSpeed)
        logging.debug("Setting QC=3 on '%d' V values which exceeded speed limit of '%f'" % (np.sum(vSpeedExceeded), maxSpeed))
        speedQcMax[vSpeedExceeded & ((speedQcMax == 1) | (speedQcMax == 2))] = 3

        timeDimension = F.createDimension("TIME")
        latitudeDimension = F.createDimension("LATITUDE", latDim)
        longitudeDimension = F.createDimension("LONGITUDE", lonDim)

        # TODO chunking of variables
        netcdfVars = {}
        for var in ACORNConstants.variableOrder:
            netcdfVars[var] = ACORNUtils.addNetCDFVariable(F, var, ACORNConstants.currentVariables[var], attributeTemplating)

        timezone = ACORNUtils.getSiteDescription(site, timestamp)['timezone']
        netcdfVars["TIME"].setncattr("local_time_zone", timezone)
        timestamp1950 = ACORNUtils.daysSince1950(timestamp)

        netcdfVars["TIME"][:] = [ timestamp1950 ]
        netcdfVars["LATITUDE"][:] = siteLats
        netcdfVars["LONGITUDE"][:] = siteLons

        netcdfVars["GDOP"][:] = np.transpose(ACORNUtils.nanToFillValue(siteGdop))

        netcdfVars["UCUR"][0] = np.transpose(ACORNUtils.nanToFillValue(UCUR))
        netcdfVars["VCUR"][0] = np.transpose(ACORNUtils.nanToFillValue(VCUR))

        netcdfVars["UCUR_sd"][0] = np.transpose(ACORNUtils.nanToFillValue(UCUR_sd))
        netcdfVars["VCUR_sd"][0] = np.transpose(ACORNUtils.nanToFillValue(VCUR_sd))

        # Number of observations
        netcdfVars["NOBS1"][0] = np.transpose(
            ACORNUtils.numberToFillValue(stationData[station1]['observation_count'], ACORNConstants.BYTE_FILL_VALUE)
        )
        netcdfVars["NOBS2"][0] = np.transpose(
            ACORNUtils.numberToFillValue(stationData[station2]['observation_count'], ACORNConstants.BYTE_FILL_VALUE)
        )

        # UCUR_quality_control and VCUR_quality_control are exactly the same
        netcdfVars["UCUR_quality_control"][0] = netcdfVars["VCUR_quality_control"][0] = np.transpose(
            ACORNUtils.nanToFillValue(speedQcMax, ACORNConstants.BYTE_FILL_VALUE)
        )

def generateCurrentFromRadialFile(radialFile, destDir):
    """
    Main function to build a current out of a radial:
     * Determines whether there are enough radials
     * Download radials
     * Builds hoursly average product
    """

    site = ACORNUtils.getSiteForStation(ACORNUtils.getStation(radialFile))
    timestamp = ACORNUtils.getTimestamp(radialFile)
    qc = ACORNUtils.isQc(radialFile)

    return generateCurrent(site, timestamp, qc, destDir)

def generateCurrent(site, timestamp, qc, destDir):
    timestamp = ACORNUtils.getCurrentTimestamp(timestamp)

    destFile = ACORNUtils.generateCurrentFilename(site, timestamp, qc)
    destFile = os.path.join(destDir, destFile)

    logging.info("Destination file: '%s'" % destFile)

    radialFileList = Util.getRadialsForSite(site, timestamp, qc)
    radialFileList = Util.getExistingRadials(radialFileList, qc)

    if Util.hasEnoughRadials(radialFileList):
        tmpDir = tempfile.mkdtemp()

        radialFileList = Util.prepareRadials(tmpDir, radialFileList, qc)

        F = Dataset(destFile, mode='w')
        Util.combineRadials(F, site, timestamp, radialFileList, qc)
        F.close()

        shutil.rmtree(tmpDir)
        logging.info("Wrote file '%s'" % destFile)
        return True
    else:
        logging.error("Not enough radials for file '%s'" % radialFile)
        return False
