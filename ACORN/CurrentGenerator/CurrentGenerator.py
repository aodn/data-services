#!/usr/bin/python

import os, sys
import urllib2
import numpy as np
from datetime import datetime, timedelta
from netCDF4 import Dataset
import logging
import argparse

import ACORNConstants
import ACORNUtils

import WERA
import CODAR

root = logging.getLogger()
root.setLevel(logging.DEBUG)

def currentFromFile(inputFile, destDir):
    inputFile = os.path.basename(inputFile)

    if ACORNUtils.isRadial(inputFile):
        return WERA.generateCurrentFromRadialFile(inputFile, destDir)
    elif ACORNUtils.isVector(inputFile):
        return CODAR.generateCurrentFromVectorFile(inputFile, destDir)
    elif ACORNUtils.isCurrent(inputFile):
        # We actually get the site, not the station, but it's the same part of
        # the file
        site = ACORNUtils.getStation(inputFile)
        timestamp = ACORNUtils.getCurrentTimestamp(ACORNUtils.getTimestamp(inputFile))
        qc = ACORNUtils.isQc(inputFile)
        siteDescription = ACORNUtils.getSiteDescription(site, timestamp)
        if siteDescription['type'] == "WERA":
            return WERA.generateCurrent(site, timestamp, qc, destDir)
        elif siteDescription['type'] == "CODAR":
            return CODAR.generateCurrent(site, timestamp, qc, destDir)
        else:
            logging.error("Unknown site type '%s'", siteDescription['type'])
            exit(1)
    else:
        logging.error("Not a vector or radial file: '%s'" % inputFile)
        exit(1)

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--source", help="source file to operate on (radial/vector file)", required=True)
    parser.add_argument("-d", "--dir", help="output directrory (must exist)", required=True)
    parser.add_argument("-D", "--delete", help="delete source file after operation", action='store_true')
    parser.add_argument("-q", "--quiet", help="reduce verbosity (errors only)", action='store_true')
    parser.add_argument("-S", "--sane", help="be sane, do not error if not enough data found", action='store_true')
    args = parser.parse_args()

    if args.quiet:
        root.setLevel(logging.ERROR)

    errorCode = currentFromFile(args.source, args.dir)
    retval = 0

    if errorCode == ACORNUtils.ACORNError.SUCCESS:
        retval = 0
    elif args.sane and errorCode == ACORNUtils.ACORNError.NOT_ENOUGH_FILES:
        retval = 0
    else:
        logging.error("Could not complete operation: '%s'" % errorCode)
        retval = 1

    if retval == 0 and args.delete and os.path.isfile(args.source):
        os.unlink(args.source)

    exit(retval)
