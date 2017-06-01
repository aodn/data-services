#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Returns the relative path of OA_Reconstruction NetCDF file

author B.Pasquer, benedicte.pasquer@utas.edu.au
"""

import os
import re
import sys


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    print 'CSIRO/Climatology/Ocean_Acidification/%s' % os.path.basename(sys.argv[1])
    exit(0)
