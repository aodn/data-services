#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Returns the relative path of a DEAKIN bathymetry file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import os
import sys

if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    path_list = ['Deakin_University', 'bathymetry']
    # append file name
    path_list.append(os.path.basename(sys.argv[1]))
    dest_path = os.path.join(*path_list)

    print dest_path
    exit(0)
