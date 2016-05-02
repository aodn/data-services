#!/usr/bin/env python
# Returns the relative path of a SRS Radiometer Dalec netcdf file
#
# author Laurent Besnard, laurent.besnard@utas.edu.au

from netCDF4 import Dataset
import datetime
import os, sys
import re
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from python.ship_callsign import ship_callsign_list

def remove_creation_date_from_filename(netcdf_filename):
    return re.sub('_C-.*$', '.nc', netcdf_filename)

def create_file_hierarchy(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    platform_code   = netcdf_file_obj.platform_code
    file_version    = netcdf_file_obj.file_version

    ships_dic = ship_callsign_list()

    if  platform_code in ships_dic:
        vessel_name = ships_dic[platform_code]
    else:
        print >>sys.stderr, 'Vessel name not known'

    if file_version == "Level 1 - calibrated radiance and irradiance data":
        file_version_code = 'FV01'
    elif file_version == "Level 0 - calibrated radiance and irradiance data":
        file_version_code = 'Fv00'
    else:
        print >>sys.stderr, 'file_version code is unknown - manual debug required'

    date_start           = datetime.datetime.strptime(netcdf_file_obj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ")
    date_end             = datetime.datetime.strptime(netcdf_file_obj.time_coverage_end, "%Y-%m-%dT%H:%M:%SZ")
    year                 = date_start.strftime('%Y')

    netcdf_filename      = 'IMOS_SRS-OC_F_' + date_start.strftime("%Y%m%dT%H%M%SZ") + '_' + platform_code + '_' + file_version_code + '_DALEC_END-' + date_end.strftime("%Y%m%dT%H%M%SZ") + '.nc'
    relative_netcdf_path = os.path.join('SRS', 'OC', 'radiometer', platform_code +  '_' + vessel_name, year, netcdf_filename)

    netcdf_file_obj.close()
    return relative_netcdf_path

if __name__== '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = create_file_hierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
