#!/usr/bin/env python
import os, sys
import shutil
import csv
from netCDF4 import Dataset, date2num
from datetime import datetime
import gzip
from tendo import singleton
import argparse
from dest_path import create_file_hierarchy
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from python.generate_netcdf_att import *
from python.lftp_sync import LFTPSync
from python.imos_logging import IMOSLogging
from python.util import list_files_recursively

OUTPUT_DIR = os.path.join(os.environ['WIP_DIR'], 'AATAMS', 'AATAMS_sattag_nrt')

def download_lftp_dat_files():
    """
    lftp download of the GTS NRT AATAMS files. Only the files not in
    OUTPUT_DIR will be downloaded
    """
    lftp_access = {
        'ftp_address'     : 'smuc.st-and.ac.uk',
        'ftp_subdir'      : '/pub/bodc',
        'ftp_user'        : '',
        'ftp_password'    : '',
        'ftp_exclude_dir' : ['corrections', 'exports', 'test'],
        'lftp_options'    : '--only-newer --exclude-glob *.dmp.gz',
        'output_dir'      : OUTPUT_DIR,
        }

    global lftp
    lftp = LFTPSync()

    if os.path.exists(os.path.join(OUTPUT_DIR, 'lftp_mirror.log')):
        return lftp.list_new_files_path_previous_log(lftp_access)

    lftp.lftp_sync(lftp_access)
    return lftp.list_new_files_path(check_file_exist=True)

def extract_dat_gz_files(list_new_dat_gz_files):
    """
    extract the *.dat.gz files downloaded into the current file dir
    """
    dat_files = []
    for file in list_new_dat_gz_files:
        if 'dat.gz' in file:
            base = os.path.basename(file)
            dest_name = os.path.join(OUTPUT_DIR, base[:-3])
            try:
                with gzip.open(file, 'rb') as infile:
                    with open(dest_name, 'w') as outfile:
                        dat_files.append(dest_name)
                        for line in infile:
                            outfile.write(line)
            except Exception, e:
                logger.error('%s is corrupted' % base)
                pass

    return dat_files

def parse_australian_tags_file():
    """
    parses the aatams_sattag_metadata.csv metadata file containing tag
    information for Australia tags only
    """
    australian_tags_filepath = os.path.join(os.environ['DATA_SERVICES_DIR'],
                                            'AATAMS',
                                            'aatams_sattag_metadata.csv')
    with open(australian_tags_filepath, 'rU') as f:
        reader = csv.reader(f)
        data   = map(tuple, reader)

    #wmo_ref = data[?][5]
    return data

def parse_dat_file(dat_file):
    """
    parses a daily *.dat file containing all the profile of each seal around the
    world
    """
    with open(dat_file, 'rb') as f:
        reader = csv.reader(f, delimiter='\t')
        data   = map(tuple, reader)

    return data

def separate_individual_profiles_from_dat(dat_file_parsed):
    """
    profiles can be separated by looking at the depth/pressure column. When this
    one increases (0 -> 600) and goes back to a lower value (4 -> 250), this is
    a new profile

    input from parse_dat_file function
    This function returns the index position of all individual profiles in a dat
    file
    """
    depth_col = [ int(x[2]) for x in dat_file_parsed ]

    depth_tmp           = -9999
    index_profile_start = list()
    index_profile_start.append(0)
    for idx, depth in enumerate(depth_col):
        if depth < depth_tmp:
            index_profile_start.append(idx)
        depth_tmp = depth

    return index_profile_start

def individual_profile_data(dat_file_parsed, index_profile_start, index_profile_end):
    """
    retrieve a profile from a dat file defined by it start and end index line
    position
    """
    profile_data      = dat_file_parsed[index_profile_start : index_profile_end]

    profile_data_wmo  = profile_data[0][0]
    profile_data_time = datetime.strptime(profile_data[0][1],
                                          "%Y-%m-%d %H:%M:%S")
    profile_data_pres = [ int(t[2]) for t in profile_data ]
    profile_data_temp = [ float(t[3]) for t in profile_data ]
    profile_data_psal = [ float(t[4]) for t in profile_data ]
    profile_data_lat  = float(profile_data[0][5])
    profile_data_lon  = float(profile_data[0][6])

    return [profile_data_wmo, profile_data_time, profile_data_pres,
            profile_data_temp, profile_data_psal, profile_data_lat,
            profile_data_lon]

def is_profile_australian(profile_data, australian_tag_list):
    """
    check if the wmo code of a profile is IMOS/Australian
    """
    device_wmo_ref_column = [t[5] for t in australian_tag_list]

    # cleaning
    device_wmo_ref_column = [x.strip(' ') for x in device_wmo_ref_column]
    device_wmo_ref_column = filter(None, device_wmo_ref_column)

    profile_wmo = profile_data[0].strip()
    return profile_wmo in device_wmo_ref_column

def get_extra_profile_att(profile_data, australian_tag_list):
    """
    get extra information from csv metadata file
    returns a dictionnary
    """
    device_wmo_ref_column = [t[5] for t in australian_tag_list]
    device_wmo_ref_column = [x.strip(' ') for x in device_wmo_ref_column]

    profile_info = dict.fromkeys(['device_id', 'tag_type', 'common_name',
                                  'release_site', 'state_country', 'age_class',
                                 'sex'])

    for idx, item in enumerate(device_wmo_ref_column):
        if item == profile_data[0]:
            profile_info = {
                'device_id':     australian_tag_list[idx][2].strip(),
                'tag_type':      australian_tag_list[idx][6].strip(),
                'common_name':   australian_tag_list[idx][7].strip(),
                'release_site':  australian_tag_list[idx][11].strip(),
                'state_country': australian_tag_list[idx][12].strip(),
                'age_class':     australian_tag_list[idx][15].strip(),
                'sex':           australian_tag_list[idx][16].strip(),
            }
    return profile_info

def create_netcdf_profile(profile_data, extra_att):
    """
    generate a netcdf file for an individual profile
    """

    netcdf_dir = os.path.join(OUTPUT_DIR, 'NETCDF')
    if not os.path.exists(netcdf_dir):
        os.makedirs(netcdf_dir)

    netcdf_file_path = os.path.join(netcdf_dir,
                                    'IMOS_AATAMS-SATTAG_TSP_%s_%s_FV00.nc'
                                    % (profile_data[1].strftime("%Y%m%dT%H%M%SZ"),
                                       profile_data[0]))
    rootgrp = Dataset(netcdf_file_path, "w", format="NETCDF4")

    rootgrp.history                   = "Created " + time.ctime(time.time())
    rootgrp.date_created              = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
    rootgrp.platform_code             = profile_data[0]
    rootgrp.geospatial_lat_min        = profile_data[5]
    rootgrp.geospatial_lat_max        = profile_data[5]
    rootgrp.geospatial_lon_min        = profile_data[6]
    rootgrp.geospatial_lon_max        = profile_data[6]
    rootgrp.geospatial_vertical_min   = min(profile_data[2])
    rootgrp.geospatial_vertical_max   = max(profile_data[2])
    rootgrp.geospatial_vertical_units = "dbar"
    rootgrp.time_coverage_start       = datetime.strftime(profile_data[1],
                                                          "%Y-%m-%dT%H:%M:%SZ")
    rootgrp.time_coverage_end         = datetime.strftime(profile_data[1],
                                                          "%Y-%m-%dT%H:%M:%SZ")

    # add extra gatts from csv metadata file
    for key in extra_att.keys():
        if extra_att[key] is not '':
            setattr(rootgrp, key, extra_att[key])

    # set up dimensions
    rootgrp.createDimension("PRES", len(profile_data[2]))
    rootgrp.createDimension("INSTANCE", 1)
    rootgrp.createDimension("length_char", 8)

    # set up variables
    rootgrp.createVariable("INSTANCE", "i4", ("INSTANCE",),
                                      fill_value=-99999)
    var_time = rootgrp.createVariable("TIME", "d", ("INSTANCE",),
                                      fill_value=
                                      get_imos_parameter_info('TIME', '_FillValue'))
    var_lat  = rootgrp.createVariable("LATITUDE", "d", ("INSTANCE",),
                                      fill_value=
                                      get_imos_parameter_info('LATITUDE', '_FillValue'))
    var_lon  = rootgrp.createVariable("LONGITUDE", "d", ("INSTANCE",),
                                      fill_value=
                                      get_imos_parameter_info('LONGITUDE', '_FillValue'))
    var_pres = rootgrp.createVariable("PRES", "f8", ("PRES", "INSTANCE"), fill_value=
                                      get_imos_parameter_info('PRES', '_FillValue'))
    var_temp = rootgrp.createVariable("TEMP",      "f8", ("PRES", "INSTANCE"),
                                      fill_value=
                                      get_imos_parameter_info('TEMP', '_FillValue'))
    var_psal = rootgrp.createVariable("PSAL",      "f8", ("PRES", "INSTANCE"),
                                      fill_value=
                                      get_imos_parameter_info('PSAL', '_FillValue'))
    var_wmo  = rootgrp.createVariable("WMO_ID",    "c" , ("INSTANCE", "length_char"))

    # add gatts and variable attributes as stored in config file
    generate_netcdf_att(rootgrp, os.path.join(os.path.dirname(__file__),
                                              'aatams_nrt_fv00_netcdf.conf'))

    # add values to variables
    var_wmo[:]  = profile_data[0]
    var_time[:] = date2num(profile_data[1], units=var_time.units,
                           calendar=var_time.calendar)
    var_pres[:] = profile_data[2]
    var_temp[:] = profile_data[3]
    var_psal[:] = profile_data[4]
    var_lat[:]  = profile_data[5]
    var_lon[:]  = profile_data[6]

    rootgrp.close()

    # get proper file hierarchy and create similar file hierarchy in WIP as it
    # would be in prod
    file_hierarchy   = create_file_hierarchy(netcdf_file_path)
    netcdf_full_path = os.path.join(netcdf_dir, file_hierarchy)
    if not os.path.exists(os.path.dirname(netcdf_full_path)):
        os.makedirs(os.path.dirname(netcdf_full_path))
    shutil.move(netcdf_file_path, netcdf_full_path)

    netcdf_file_path = netcdf_full_path
    return netcdf_file_path

def move_to_incoming(file):
    incoming_dir = os.path.join(os.environ['INCOMING_DIR'], 'AATAMS',
                                'AATAMS_SATTAG_NRT')
    if not os.path.exists(incoming_dir):
        logger.error('incoming dir %s does not exist - process arboted' %
                     incoming_dir)
        exit(1)

    incoming_dir = os.path.join(incoming_dir)
    if not os.path.exists(os.path.join(incoming_dir, os.path.basename(file))):
        shutil.move(file, incoming_dir)
    else:
        logger.warning('File already exist in INCOMING_DIR: %s'
                       % os.path.basename(file))

def main(force_reprocess_all=False, manifest=True):
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # setup logging
    log_filepath = os.path.join(OUTPUT_DIR, 'aatams_nrt.log')
    logging      = IMOSLogging()
    global logger
    logger       = logging.logging_start(log_filepath)
    logger.info('Process AATAMS NRT')

    # force the recreation of all netcdf file and push to incoming
    if force_reprocess_all:
        list_new_dat_gz_files = list_files_recursively(OUTPUT_DIR, '*.dat.gz')
    else:
        list_new_dat_gz_files = download_lftp_dat_files()
        lftp.close()

    dat_files             = extract_dat_gz_files(list_new_dat_gz_files)
    australian_tag_list   = parse_australian_tags_file()

    netcdf_file_path_set = set()
    for dat_file in dat_files:
        logger.info('Processing %s' % dat_file)
        dat_file_parsed       = parse_dat_file(dat_file)
        index_profiles_start  = separate_individual_profiles_from_dat(dat_file_parsed)

        for idx, profile in enumerate(index_profiles_start[:-1]):
            profile_data = individual_profile_data(dat_file_parsed, profile,
                                                   index_profiles_start[idx+1])

            if is_profile_australian(profile_data, australian_tag_list):
                extra_atts       = get_extra_profile_att(profile_data,
                                                         australian_tag_list)
                netcdf_file_path = create_netcdf_profile(profile_data, extra_atts)
                netcdf_file_path_set.add(netcdf_file_path)
            else:
                logger.warning(("%s wmo is not an Australian tag/is not in "
                                "aatams_sattag_metadata.csv") % profile_data[0])

        os.remove(dat_file)

    # moves manifest_file or netcdf files to incoming. default is netcdf file
    if not manifest:
        for file in netcdf_file_path_set:
            move_to_incoming(file)
    else:
        manifest_file = os.path.join(OUTPUT_DIR, 'manifest')
        with open(manifest_file, 'w') as f:
            for file in netcdf_file_path_set:
                f.write("%s\n" % file)
        move_to_incoming(manifest_file)

    logging.logging_stop()

def parse_arg():
    """
    create optional script arg -f to to force the reprocess of all dat files
    already downloaded
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--force-reprocess",
                        help="reprocess all dat files", action="store_true")
    args = parser.parse_args()

    return args


if __name__ == '__main__':
    # will sys.exit(-1) if other instance is running
    me = singleton.SingleInstance()
    """
    ./AATAMS_sattag_nrt.py -h       Help
    ./AATAMS_sattag_nrt.py -f       Force reprocess dat files
    ./AATAMS_sattag_nrt.py          Normal process
    """
    args = parse_arg()
    if args.force_reprocess:
        main(manifest=True, force_reprocess_all=True)
    else:
        main(manifest=True)
