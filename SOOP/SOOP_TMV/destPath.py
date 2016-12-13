#!/usr/bin/env python
# -*- coding: utf-8 -*-
import ntpath
import os
import sys


def destination_path(ncFile):
        """
        # Determine path for SOOP-TMV DM files
        # eg file IMOS_SOOP-TMV_TSB_20130101T083421Z_VLST_FV02_transect-D2M_END-20130101T185741Z.nc
        """
        ncFile = ntpath.basename(ncFile)
        fileparts = ncFile.split("_")

        # the file name must have at least 6 component parts to be valid
        if len(fileparts) > 5:
            facility = fileparts[1] # <Facility-Code>
            year = fileparts[3][:4] # year out of <Start-date>
            month = fileparts[3][4:6]

            # check for the code in the ships
            code = fileparts[4]
            if code == "VLST":

                platform = "%s_Spirit-of-Tasmania-1" % code

                product = "transect"
                targetDir = os.path.join('SOOP', facility, platform, product, year, month)

                return targetDir

            else:
                err = "Hierarchy not created for '%s'" % ncFile
                print >>sys.stderr, err
                return None

if __name__=='__main__':
    # read filename from command line

    path = destination_path(sys.argv[1])

    if not path:
        exit(1)

    print path
    exit(0)
