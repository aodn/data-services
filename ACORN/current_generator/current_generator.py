#!/usr/bin/python

import argparse
import logging
import os
import sys
import urllib2
from datetime import datetime, timedelta

import numpy as np
from netCDF4 import Dataset

import acorn_constants
import acorn_utils
import codar
import wera

root = logging.getLogger()
root.setLevel(logging.DEBUG)

def current_from_file(input_file, dest_dir):
    input_file = os.path.basename(input_file)

    timestamp = acorn_utils.get_current_timestamp(acorn_utils.get_timestamp(input_file))
    qc = acorn_utils.is_qc(input_file)
    if acorn_utils.is_radial(input_file):
        site = acorn_utils.get_site_for_station(acorn_utils.get_station(input_file))
    elif acorn_utils.is_hourly(input_file):
        # We actually get the site, it's the same part of the file
        site = acorn_utils.get_station(input_file)
    else:
        logging.error("Not a radial nor hourly file: '%s'" % input_file)
        exit(1)
        
    site_description = acorn_utils.get_site_description(site, timestamp)
    if site_description['type'] == "WERA":
        if acorn_utils.is_radial(input_file):
            return wera.generate_current_from_radial_file(input_file, dest_dir)
        else:
            # we have an hourly file
            return wera.generate_current(site, timestamp, qc, dest_dir)

    elif site_description['type'] == "CODAR":
        logging.info("We do nothing, ACORN UWA is in charge of generating CODAR hourly vector currents")
        return acorn_utils.ACORN_STATUS.SUCCESS
    else:
        logging.error("Unknown site type '%s'", site_description['type'])
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

    error_code = current_from_file(args.source, args.dir)
    retval = 0

    if error_code == acorn_utils.ACORN_STATUS.SUCCESS:
        retval = 0
    elif args.sane and error_code in [acorn_utils.ACORN_STATUS.NOT_ENOUGH_FILES, acorn_utils.ACORN_STATUS.NO_CURRENT_DATA]:
        retval = 0
    else:
        logging.error("Could not complete operation: '%s'" % error_code)
        retval = 1

    if retval == 0 and args.delete and os.path.isfile(args.source):
        os.unlink(args.source)

    exit(retval)
