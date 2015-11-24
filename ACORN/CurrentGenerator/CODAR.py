#!/usr/bin/python

import os, sys
import numpy as np
import tempfile
import shutil
from datetime import datetime, timedelta
from netCDF4 import Dataset
import logging

import ACORNConstants
import ACORNUtils
import ACORNQC

class Util:
    @staticmethod
    def hasEnoughVectors(radialFileList):
        # We will have only 1 station and 1 file... :)
        for station, radialFiles in radialFileList.iteritems():
            return len(radialFiles) > 0

    @staticmethod
    def getVectorBase():
        return ACORNConstants.VECTOR_BASE

    @staticmethod
    def getExistingVectors(vectorFileList):
        return ACORNUtils.getExistingFiles(Util.getVectorBase(), vectorFileList)

    @staticmethod
    def prepareVectors(tmpDir, vectorFileList):
        return ACORNUtils.prepareFiles(tmpDir, Util.getVectorBase(), vectorFileList)

    @staticmethod
    def getVectorsForSite(site, timestamp):
        vectors = {}
        station = site # Station sending files is equal to the site name
        vectors[station] = [ ACORNUtils.filesForStation(station, timestamp, "V", "00", "sea-state")[0] ]
        return vectors

    @staticmethod
    def adjustGrid(data, lonDim, latDim):
        """
        Data on the CODAR grid is ordered from bottom left to top right and we
        need it ordered so a reshape and reversing along the Y axis is required
        """
        shapedData = np.reshape(data, (latDim, lonDim))

        # After the array is shaped, we reverse it along the Y axis
        shapedData = np.flipud(shapedData)

        # Return it as a 1 dimensional array
        return shapedData.reshape((1, lonDim * latDim))[0]

    @staticmethod
    def fixGdopGrid(gdop, lonDim, latDim):
        # Fix gdop grid to align properly. It is stored awkwardly in the first
        # place
        return np.transpose(gdop.reshape((lonDim, latDim))).flatten().reshape((lonDim, latDim))

    @staticmethod
    def transformVector(F, site, timestamp, vectorFileList):
        siteDescription = ACORNUtils.getSiteDescription(site, timestamp)
        latDim = siteDescription['dimensions']['lat']
        lonDim = siteDescription['dimensions']['lon']
        arraySize = latDim * lonDim

        siteGrid = ACORNUtils.getGridForSite(site, timestamp, False)

        siteLons = Util.adjustGrid(siteGrid['lon'], lonDim, latDim)
        siteLats = Util.adjustGrid(siteGrid['lat'], lonDim, latDim)

        siteGdop = ACORNUtils.getGdopForSite(site, timestamp, False, lonDim * latDim)
        siteGdop = Util.fixGdopGrid(siteGdop, lonDim, latDim)

        attributeTemplating = ACORNConstants.attributeTemplatingCODAR

        # Do not pre fill with fill values this dataset, we do it ourselves
        F.set_fill_off()

        stationData = {}

        station = vectorFileList.keys()[0]
        sourceVectorFile = vectorFileList[station][0]

        stationData[station] = {}
        for var, dtype in ACORNConstants.varMappingCodar.iteritems():
            stationData[station][var] = np.array(np.full((lonDim, latDim), np.nan, dtype=dtype))

        ds = Dataset(sourceVectorFile, mode='r')
        posArray = np.array(ds.variables['POSITION'])
        posArray = posArray - 1
        for var, dtype in ACORNConstants.varMappingCodar.iteritems():
            if var in ds.variables:
                stationData[station][var] = ACORNUtils.expandArray(
                    posArray, ds.variables[var], arraySize, dtype)
            else:
                logging.warning("Variable '%s' does not exist in NetCDF file" % var)

            # Arrays are flipped (going bottom to top), flip them over the V
            # axis
            stationData[station][var] = Util.adjustGrid(stationData[station][var], lonDim, latDim)

            # Reshape to a grid
            stationData[station][var] = stationData[station][var].reshape(lonDim, latDim)

        attributeTemplating['siteAbstract'] = str(ds.getncattr('abstract'))
        attributeTemplating['prevHistory'] = str(ds.getncattr('history'))
        attributeTemplating['timeCoverageDuration'] = str(ds.getncattr('time_coverage_duration'))
        attributeTemplating['id'] = str(ds.getncattr('id'))

        ds.close()

        ACORNUtils.fillGlobalAttributes(F, site, timestamp, False, attributeTemplating)

        # Build a QC matrix with zeros. The only QC check we will perform here
        # is the GDOP one
        stationData[station]["speed_qc"] = np.zeros((lonDim, latDim), dtype=np.float32)

        # Eliminate points with bad GDOP (like in WERA)
        ACORNQC.gdopMasking(
            stationData,
            siteGdop,
            "speed_qc"
        )

        UCUR = stationData[station]['ssr_Surface_Eastward_Sea_Water_Velocity']
        VCUR = stationData[station]['ssr_Surface_Northward_Sea_Water_Velocity']

        UCUR_sd = stationData[station]['ssr_Surface_Eastward_Sea_Water_Velocity_Standard_Error']
        VCUR_sd = stationData[station]['ssr_Surface_Northward_Sea_Water_Velocity_Standard_Error']

        speedQcMax = stationData[station]["speed_qc"]
        speedQcMax[np.isnan(UCUR)] = np.nan
        speedQcMax[np.isnan(VCUR)] = np.nan

        timeDimension = F.createDimension("TIME")
        latitudeDimension = F.createDimension("I", latDim)
        longitudeDimension = F.createDimension("J", lonDim)

        # TODO chunking of variables
        netcdfVars = {}
        for var in ACORNConstants.variableOrder:
            varInfo = ACORNConstants.currentVariables[var]
            # Replace LATITUDE -> I, LONGITUDE -> J
            dims = varInfo['dimensions']
            if "LATITUDE" in dims:
                dims[dims.index("LATITUDE")] = "I"

            if "LONGITUDE" in dims:
                dims[dims.index("LONGITUDE")] = "J"

            if var == "LATITUDE" or var == "LONGITUDE":
                dims = [ "I", "J" ]

            varInfo['dimensions'] = dims

            netcdfVars[var] = ACORNUtils.addNetCDFVariable(F, var, varInfo, attributeTemplating)

        netcdfVars["TIME"].setncattr("local_time_zone", siteDescription['timezone'])
        timestamp1950 = ACORNUtils.daysSince1950(timestamp)

        netcdfVars["TIME"][:] = [ timestamp1950 ]
        netcdfVars["LATITUDE"][:] = ACORNUtils.nanToFillValue(siteLats)
        netcdfVars["LONGITUDE"][:] = ACORNUtils.nanToFillValue(siteLons)

        netcdfVars["GDOP"][:] = ACORNUtils.nanToFillValue(siteGdop)

        netcdfVars["UCUR"][0] = ACORNUtils.nanToFillValue(UCUR)
        netcdfVars["VCUR"][0] = ACORNUtils.nanToFillValue(VCUR)

        netcdfVars["UCUR_sd"][0] = ACORNUtils.nanToFillValue(UCUR_sd)
        netcdfVars["VCUR_sd"][0] = ACORNUtils.nanToFillValue(VCUR_sd)

        # Find all non-nan and non-zero matrices in seasonde_LLUV_S[2-6]CN and
        # use it as NOBS2
        nobsOptions = []
        for varName in ACORNConstants.CODAR_NOBS_VARIABLES:
            stationData[station][varName]
            if not np.all(np.logical_or(np.isnan(stationData[station][varName]), stationData[station][varName]==0)):
                nobsOptions.append(stationData[station][varName])

        if len(nobsOptions) < 2:
            logging.error("Not enough non-nan seasonde_LLUV_SXCN matrices found to build NOBS variable")
            exit(1)

        # Use first 2 non-nan NOBS matrices we have found
        for i in [0, 1]:
            nobsVariable = "NOBS%d" % (i+1)
            netcdfVars[nobsVariable][0] = ACORNUtils.nanToFillValue(
                nobsOptions[i],
                ACORNConstants.BYTE_FILL_VALUE). \
            reshape((lonDim, latDim))

        # UCUR_quality_control and VCUR_quality_control are exactly the same
        netcdfVars["UCUR_quality_control"][0] = netcdfVars["VCUR_quality_control"][0] = \
            ACORNUtils.nanToFillValue(speedQcMax, ACORNConstants.BYTE_FILL_VALUE).reshape((lonDim, latDim))


def currentFromVectors(vectorFile, destDir):
    """
    Main function to build a current from a vector
    """

    vectorFile = os.path.basename(vectorFile)

    station = site = ACORNUtils.getStation(vectorFile)
    timestamp = ACORNUtils.getTimestamp(vectorFile)

    destFile = ACORNUtils.generateCurrentFilename(site, timestamp, False)
    destFile = os.path.join(destDir, destFile)

    logging.info("Destination file: '%s'" % destFile)

    vectorFileList = Util.getVectorsForSite(site, timestamp)
    vectorFileList = Util.getExistingVectors(vectorFileList)

    if Util.hasEnoughVectors(vectorFileList):
        tmpDir = tempfile.mkdtemp()

        vectorFileList = Util.prepareVectors(tmpDir, vectorFileList)

        F = Dataset(destFile, mode='w')
        Util.transformVector(F, site, timestamp, vectorFileList)
        F.close()

        shutil.rmtree(tmpDir)
        logging.info("Wrote file '%s'" % destFile)
        return True
    else:
        logging.error("Not enough vectors for file '%s'" % vectorFile)
        return False
