#!/usr/bin/env python
# Returns the relative path to create for a SOOP XBT DM netcdf file
#
# author Laurent Besnard, laurent.besnard@utas.edu.au

import datetime
import os
import sys

from netCDF4 import Dataset


def create_file_hierarchy(netcdfFilePath):
    F                    = Dataset(netcdfFilePath, mode='r')
    xbt_line             = F.XBT_line
    xbt_line_description = F.XBT_line_description
    date_start           = datetime.datetime.strptime(F.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ")
    year_line            = date_start.strftime('%Y')
    F.close()

    soop_xbt_dm_path = os.path.join('SOOP', 'SOOP-XBT', 'DELAYED')

    # case for 'indian-ocean' 'tasman-sea' and 'SO_Southern-Ocean'
    if xbt_line.startswith("PX") or xbt_line.startswith("IX"):
        xbt_line = "Line_%s_%s" % (xbt_line, xbt_line_description)

    return os.path.join(
        soop_xbt_dm_path,
        xbt_line,
        str(year_line),
        os.path.basename(netcdfFilePath)
    )

if __name__== '__main__':
    # Read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = create_file_hierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
