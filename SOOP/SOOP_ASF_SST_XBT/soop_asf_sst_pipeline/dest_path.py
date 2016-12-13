#!/usr/bin/env python
# -*- coding: utf-8 -*-

import ntpath
import os
import sys

from ship_callsign import ship_callsign_list


class SoopBomAsfSstDestPath:

    def __init__(self):
        self.ships      = ship_callsign_list()
        self.data_codes = {'FMT':'flux_product',
                           'MT':'meteorological_sst_observations'}

    def dest_path(self, nc_file):
        """
        # eg file IMOS_SOOP-SST_T_20081230T000900Z_VHW5167_FV01.nc
        # IMOS_SOOP-ASF_MT_20150913T000000Z_ZMFR_FV01_C-20150914T042207Z.nc
        # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_<Product-Type>_END-<End-date>_C-<Creation_date>_<PARTX>.nc
        """
        nc_file    = ntpath.basename(nc_file)
        file_parts = nc_file.split("_")

        # the file name must have at least 6 component parts to be valid
        if len(file_parts) > 5:
            facility = file_parts[1] # <Facility-Code>
            year     = file_parts[3][:4] # year out of <Start-date>

            # check for the code in the ships
            code = file_parts[4]
            if code in self.ships:
                platform = code + "_" + self.ships[code]

                if facility == "SOOP-ASF":
                    if file_parts[2] in self.data_codes:
                        product    = self.data_codes[file_parts[2]]
                        target_dir = os.path.join("SOOP", facility, platform, product, year)
                        return os.path.join(target_dir, nc_file)

                    else:
                        err = "Hierarchy not created for "+ nc_file
                        print >>sys.stderr, err
                        return None

                else:
                    # soop sst
                    target_dir = os.path.join('SOOP', facility, platform, year)

                    # files that contain '1-min-avg.nc' get their own sub folder
                    if "1-min-avg" in nc_file:
                        target_dir = os.path.join(target_dir, "1-min-avg")

                    return os.path.join(target_dir, nc_file)


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    dest_path        = SoopBomAsfSstDestPath()
    destination_path = dest_path.dest_path(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
