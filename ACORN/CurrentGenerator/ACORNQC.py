#!/usr/bin/python

import logging
import numpy as np
import ACORNConstants
import ACORNUtils

"""
The stationData struct is something that looks like:
stationData = {
    "station1": {
        "speed": np.array([...]),
        "error": np.array([...]),
        ...
    },
    "station2": {
        "speed": np.array([...]),
        "error": np.array([...]),
        ...
    }
}
"""

def nanAll(stationData, station, pos):
    """
    Fill NaNs in all given indices for stationData struct, iterating on all
    matrices of stationData

    @type stationData: dict
    @param stationData: Hash with all site/station data. Modified in place

    @type station: station
    @param station: Station key to null values for

    @type pos: np.array
    @param pos: Array mask with True where values should become NaN
    """
    for k, matrix in stationData[station].iteritems():
        matrix[pos] = np.nan

def removeLowObservationCount(stationData, speedKey, minObservations=ACORNConstants.WERA_MIN_RADIALS_PER_STATION):
    """
    Fill NaNs in all indices with not enough observation count

    @type stationData: dict
    @param stationData: Hash with all site/station data. Modified in place

    @type speedKey: string
    @param speedKey: Speed hash key in hash

    @type minObservations: int
    @param minObservations: Threshold for low observations
    """

    for station in stationData.keys():
        obsCount = np.sum(np.isfinite(stationData[station][speedKey]), axis=0)

        iNotEnoughObs = obsCount < minObservations
        logging.info("Removed '%d' values with observations < '%d'" % (np.sum(iNotEnoughObs), minObservations))
        iNotEnoughObs = np.expand_dims(iNotEnoughObs, axis=0)

        # NAN all stations, not just the inspected station
        for stn in stationData.keys():
            xAxis = stationData[stn][speedKey].shape[0]
            iNotEnoughObsMask = np.repeat(iNotEnoughObs, xAxis, axis=0)
            nanAll(stationData, stn, iNotEnoughObsMask)

def getExceededSpeedLimit(speed, maxSpeed):
    """
    Return all indices with speed limit exceeding maxSpeed, ignoring NaNs

    @type speed: np.array
    @param speed: Array with speed values

    @type speedKey: string
    @param speedKey: Speed hash key in hash

    @type maxSpeed: float
    @param maxSpeed: Maximum speed

    @rtype: np.array
    @return: Array with True values where speed limit exceeded
    """
    speedAbs = np.abs(np.nan_to_num(speed))
    return speedAbs >= maxSpeed

def enforceSpeedLimit(stationData, speedKey, maxSpeed):
    """
    Fill NaNs where speed limit is exceeded

    @type stationData: dict
    @param stationData: Hash with all site/station data. Modified in place

    @type speedKey: string
    @param speedKey: Speed hash key in hash

    @type maxSpeed: float
    @param maxSpeed: Maximum speed
    """

    for station in stationData.keys():
        speedMatrix = np.array(stationData[station][speedKey])
        iSpeedExceeded = getExceededSpeedLimit(speedMatrix, maxSpeed)

        logging.info("Removed '%d' values which exceeded speed limit of '%f'" % (np.sum(iSpeedExceeded), maxSpeed))
        nanAll(stationData, station, iSpeedExceeded)

def enforceSignalToNoiseRatio(stationData, braggKey, qcKey, qcMode=False, minBragg=8.0, suspiciousBragg=10.0):
    """
    Enforce signal to noise ratio. Fill NaNs where values are smaller than
    minBragg.
    Set QC flag to 2 where minBragg <= value < suspiciousBragg and QC flag == 1
    if qcMode==True.

    @type stationData: dict
    @param stationData: Hash with all site/station data. Modified in place

    @type braggKey: string
    @param braggKey: Bragg key in hash

    @type qcKey: string
    @param qcKey: QC key in hash

    @type minBragg: float
    @param minBragg: Minimum bragg, below that, set values to NaN

    @type minBragg: float
    @param suspiciousBragg: Suspicious bragg, below that, set QC flag to 2
    """

    for station in stationData.keys():
        braggMatrix = np.array(stationData[station][braggKey])
        qcMatrix = np.array(stationData[station][qcKey])

        # Ignore nans for both matrices
        braggMatrix[np.isnan(braggMatrix)] = np.inf
        qcMatrix[np.isnan(qcMatrix)] = np.inf

        iLowBragg = minBragg > braggMatrix
        logging.info("Removed '%d' values with bragg < '%f'" % (np.sum(iLowBragg), minBragg))

        nanAll(stationData, station, iLowBragg)

        if qcMode:
            iGoodQC = qcMatrix == 1
            iSuspiciousBraggWithGoodQc = (braggMatrix < suspiciousBragg) & (iGoodQC)

            logging.info("Setting QC=2 on '%d' values with bragg < '%f' and QC == 1" % (np.sum(iSuspiciousBraggWithGoodQc), suspiciousBragg))
            stationData[station][qcKey][iSuspiciousBraggWithGoodQc] = 2

def discardQcRange(stationData, qcKey, qcMode=False, minQc=1, maxQc=2):
    """
    Fill NaNs for every value that does not meet maxQc >= QC >= minQc.
    Notice you have to pass qcMode=True for this function to do anything!!

    @type stationData: dict
    @param stationData: Hash with all site/station data. Modified in place

    @type minQc: int
    @param minQc: Lower end of QC range (usually 1)

    @type maxQc: int
    @param maxQc: Upper end of QC range (usually 2)
    """

    if not qcMode:
        return

    for station in stationData.keys():
        qcMatrix = stationData[station][qcKey]
        qcMatrix[np.isnan(qcMatrix)] = minQc # Treat all nan values as good
        iGoodQc = (minQc <= qcMatrix) & (qcMatrix <= maxQc)
        iBadQc = -iGoodQc

        logging.info("Removed '%d' values, leaving only values with '%d' <= QC <= '%d'" % (np.sum(iBadQc), minQc, maxQc))
        nanAll(stationData, station, iBadQc)

def gdopMasking(stationData, gdop, qcKey, qcMode=False, badGdop=20, suspiciousGdop=30):
    """
    Set QC flags for every value that has a problematic GDOP angle.
    In non-QC mode set a default value of 0, in QC mode set it to 1.

    A problematic GDOP is when the angle betwen the radials is too small to get
    an accurate measurement. That is values of -20 < x < 20 or x > 160 or
    x < -160. In those cases the radials are /almost/ at the same angle, and
    each of them does not necessarily give more information compared to having
    just one radial.

    When the GDOP angle is under the badGdop range, QC flag will set to 4, in
    angles that are badGdop < x < suspiciousGdop, the flag will be set to 3.

    This function expands the GDOP array to be a matrix like in stationData and
    then masks the stationData with the GDOP matrix.

    @type stationData: dict
    @param stationData: Hash with all site/station data. Modified in place

    @type gdop: np.array
    @param gdop: Numpy array with all GDOP angles. gdop[x] corresponds to
                 stationData[station][qcKey][x]

    @type qcMode: bool
    @param qcMode: In QC mode the default QC flag is 1, 0 otherwise

    @type badGdop: float
    @param badGdop: Bad GDOP, set QC flag to 4

    @type suspiciousGdop: float
    @param suspiciousGdop: Suspicious GDOP, set QC flag to 3
    """

    # Set an array with the distance of GDOP from 0 or 180
    # For instance, the "fate" of a 165 angle is the same as 15
    # Or, 130 and 50, etc. You get the idea...
    gdopNormalized = np.minimum(np.abs(180 - gdop), np.abs(0 - gdop))

    iBadGdop = gdopNormalized <= badGdop
    iSuspiciousGdop = (badGdop < gdopNormalized) & (gdopNormalized <= suspiciousGdop)

    logging.info("Setting QC=3 on '%d' values with '%f' < GDOP <= '%f'" % (np.sum(iSuspiciousGdop), badGdop, suspiciousGdop))
    logging.info("Setting QC=4 on '%d' values with GDOP <= '%f'" % (np.sum(iBadGdop), badGdop))

    # In QC mode, default GDOP QC will be 1
    # Otherwise use 0 by default (no QC)
    if qcMode:
        defaultQcValue = 1
    else:
        defaultQcValue = 0

    gdopQcMask = np.full(gdopNormalized.shape, defaultQcValue, dtype=np.byte)

    gdopQcMask[iSuspiciousGdop] = 3
    gdopQcMask[iBadGdop] = 4

    for station in stationData.keys():
        qcMatrix = stationData[station][qcKey]

        qcMatrix = np.maximum(qcMatrix, gdopQcMask)

        # All nans can become zeros or ones, depending on qcMode
        qcMatrix[np.isnan(qcMatrix)] = defaultQcValue

        stationData[station][qcKey] = qcMatrix

