#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Returns the relative path of a CARS NetCDF file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import os
import re
import sys


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    pattern = 'CARS(\d+)_.*\.nc'
    year    = re.search(pattern, sys.argv[1]).group(1)
    print 'CSIRO/Climatology/CARS/%s/AODN-product/%s' % (year, os.path.basename(sys.argv[1]))
    exit(0)
