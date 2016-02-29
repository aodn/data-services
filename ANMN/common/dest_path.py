#! /usr/bin/env python

"""
Return the path / object id to publish an ANMN NetCDF file.

Input:
  incoming netCDF file

Output:
  relative path where file should go, including filename
  e.g. IMOS/ANMN/NRS/NRSMAI/Biogeochem_profiles/original_file_name.nc

Assume: (will be checked by handler)
 * File is netCDF
 * File was produced by the Toolbox
 * Site code has been validated in checker (if exists)
"""

import sys
from file_classifier import MooringFileClassifier, FileClassifierException



if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    input_path = sys.argv[1]

    try:
        dest_path = MooringFileClassifier.dest_path(input_path)
    except FileClassifierException, e:
        print >>sys.stderr, e
        exit(1)

    print dest_path
    exit(0)
