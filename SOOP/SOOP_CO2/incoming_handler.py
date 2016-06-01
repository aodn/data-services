#!/usr/bin/python

import os
import sys
import tempfile
#import logging

#root = logging.getLogger()
#root.setLevel(logging.DEBUG)

if 'DATA_SERVICES_DIR' in os.environ:
    sys.path.append(os.environ['DATA_SERVICES_DIR'])

sys.path.append("/vagrant/src/data-services/lib/python")

import log
import s3
import util

from netCDF4 import Dataset
def ships():
    return {
        'VNAA': 'Aurora-Australis',
        'VLHJ': 'Southern-Surveyor',
        'FHZI': 'Astrolabe',
        'ZMFR': 'Tangaroa'
    }

def dest_path(ncFile):
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
        if code in ships():

            platform = code + "_" + ships()[code]

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

            targetDir = os.path.join('IMOS', 'SOOP', facility, platform, year, cruise_id)
            return targetDir

        else:
            raise Exception("Hierarchy not created for '%s'" % ncFile)

def get_nc_file(file_list):
    for f in file_list:
        if util.has_extension(f, "nc"):
            return f

    raise "Could not find .nc file in zip archive"

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    file = sys.argv[1]

    log.log_info("Handling SOOP CO2 zip file '%s'" % file)

    tmp_dir = tempfile.mkdtemp()
    os.chmod(tmp_dir, 0755)
    file_list = util.unzip_file(file, tmp_dir)

    nc_file = os.path.join(tmp_dir, get_nc_file(file_list))
    file_path = os.path.join(dest_path(nc_file))

    s3.put(nc_file, os.path.join(file_path, os.path.basename(nc_file)))

    for f in os.listdir(tmp_dir):
        s3.put(
            os.path.join(tmp_dir, f),
            os.path.join(file_path, os.path.basename(f)),
            index=False
        )

    os.rmdir(tmp_dir)
    #os.unlink(file)
