#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, sys
from netCDF4 import Dataset

sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from python.ship_callsign import ship_callsign_list


class soop_co2_dest_path:

    def __init__(self):
        self.ships = ship_callsign_list()

    def dest_path(self, nc_file):
        """
        # eg : IMOS_SOOP-CO2_GST_20121027T045200Z_VLHJ_FV01.nc
        # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc
        """
        nc_file_basename = os.path.basename(nc_file)
        file = nc_file_basename.split("_")

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
                    F = Dataset(nc_file, mode='r')
                except:
                    print >>sys.stderr, "Failed to open NetCDF file '%s'" % nc_file
                    return None
                # add cruise_id
                cruise_id = getattr (F, 'cruise_id', '')

                F.close()

                if not cruise_id:
                    print >>sys.stderr, "File '%s' has no cruise_id attribute" % nc_file
                    return None

                target_dir = facility + os.path.sep + platform + os.path.sep + year + os.path.sep + cruise_id

                return target_dir

            else:
                print >>sys.stderr, "Hierarchy not created for '%s'" % nc_file
                return None


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    dest_path = soop_co2_dest_path()

    answer = dest_path.dest_path(sys.argv[1])

    if not answer:
        exit(1)

    print answer
    exit(0)
