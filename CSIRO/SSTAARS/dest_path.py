#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Returns the relative path of a SSTAARS NetCDF file
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

    print 'CSIRO/Climatology/SSTAARS/2017/AODN-product/%s' % (os.path.basename(sys.argv[1]))
    exit(0)
