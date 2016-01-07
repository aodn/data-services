#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os,sys
import ntpath

class SoopBomAsfSstDestPath:

    def __init__(self):
        self.ships = {
            'VLST'    :'Spirit-of-Tasmania-1',
            'VNSZ'    :'Spirit-of-Tasmania-2',
            'VHW5167' :'Sea-Flyte',
            'VNVR'    :'Iron-Yandi',
            'VJQ7467' :'Fantasea',
            'VNAH'    :'Portland',
            'V2BJ5'   :'ANL-Yarrunga',
            'VROB'    :'Highland-Chief',
            '9HA2479' :'Pacific-Sun',
            'VNAA'    :'Aurora-Australis',
            'VLHJ'    :'Southern-Surveyor',
            'FHZI'    :'Astrolabe',
            'C6FS9'   :'Stadacona',
            'V2BF1'   :'Florence',
            'V2BP4'   :'Vega-Gotland',
            'A8SW3'   :'Buxlink',
            'ZMFR'    :'Tangaroa',
            'VRZN9'   :'Pacific-Celebes',
            'VHW6005' :'RV-Linnaeus',
            'HSB3402' :'MV-Xutra-Bhum',
            'HSB3403' :'MV-Wana-Bhum',
            'VRUB2'   :'Chenan',
            'VNCF'    :'Cape-Ferguson',
            'VRDU8'   :'OOCL-Panama',
            '9V2768'  :'Wakmatha'
        }

        self.data_codes = {'FMT':'flux_product','MT':'meteorological_sst_observations'}


    def destPath(self,ncFile):
        """
        # eg file IMOS_SOOP-SST_T_20081230T000900Z_VHW5167_FV01.nc
        # IMOS_SOOP-ASF_MT_20150913T000000Z_ZMFR_FV01_C-20150914T042207Z.nc
        # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_<Product-Type>_END-<End-date>_C-<Creation_date>_<PARTX>.nc

        """
        ncFile    = ntpath.basename(ncFile)
        fileparts = ncFile.split("_")


        # the file name must have at least 6 component parts to be valid
        if len(fileparts) > 5:
            facility = fileparts[1] # <Facility-Code>
            year     = fileparts[3][:4] # year out of <Start-date>

            # check for the code in the ships
            code = fileparts[4]
            if code in self.ships:
                platform = code + "_" + self.ships[code]

                if facility == "SOOP-ASF":
                    if fileparts[2] in self.data_codes:
                        product   = self.data_codes[fileparts[2]]
                        targetDir = os.path.join("SOOP", facility, platform, product, year)
                        return os.path.join(targetDir,ncFile)

                    else:
                        err = "Hierarchy not created for "+ ncFile
                        print >>sys.stderr, err
                        return None

                else:
                    # soop sst
                    targetDir = os.path.join('SOOP', facility, platform, year)

                    # files that contain '1-min-avg.nc' get their own sub folder
                    if "1-min-avg" in ncFile:
                        targetDir = os.path.join(targetDir, "1-min-avg")

                    return os.path.join(targetDir,ncFile)


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destPath         = SoopBomAsfSstDestPath()
    destination_path = destPath.destPath(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
