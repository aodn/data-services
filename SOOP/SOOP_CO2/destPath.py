#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, sys
from netCDF4 import Dataset

class soop_co2_dest_path:

    def __init__(self):
        self.ships = {
            'VNAA' : 'Aurora-Australis',
            'VLHJ' : 'Southern-Surveyor',
            'FHZI' : 'Astrolabe',
            'ZMFR' : 'Tangaroa'
        }

    def destPath(self, ncFile):
        """

        # eg : IMOS_SOOP-CO2_GST_20121027T045200Z_VLHJ_FV01.nc
        # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc

        """
        ncFileBasename = os.path.basename(ncFile)
        file = ncFileBasename.split("_")

        facility = file[1] # <Facility-Code>

        # the file name must have at least 6 component parts to be valid
        if len(file) > 5:

            year = file[3][:4] # year out of <Start-date>

            # check for the code in the ships
            code = file[4]
            if code in self.ships:

                platform = code + "_" + self.ships[code]

                # open the file
                try:
                    F = Dataset(ncFile, mode='r')
                except:
                    print >>sys.stderr, "Failed to open NetCDF file '%s'" % ncFile
                    return None
                # add cruise_id
                cruise_id = getattr (F, 'cruise_id', '')

                F.close()

                if not cruise_id:
                    print >>sys.stderr, "File '%s' has no cruise_id attribute" % ncFile
                    return None

                targetDir = facility + os.path.sep + platform + os.path.sep + year + os.path.sep + cruise_id

                return targetDir

            else:
                print >>sys.stderr, "Hierarchy not created for '%s'" % ncFile
                return None

if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destPath = soop_co2_dest_path()

    answer = destPath.destPath(sys.argv[1])

    if not answer:
        exit(1)

    print answer
    exit(0)
