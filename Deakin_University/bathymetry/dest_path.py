#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Returns the relative path of a DEAKIN bathymetry NetCDF file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import os
import sys

if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

if 'PPB_Bathy_50m_Clipped.nc' == os.path.basename(sys.argv[1]):
    print 'Deakin_University/bathymetry/PPB_Bathy_50m_Clipped.nc'
    exit(0)
