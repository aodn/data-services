#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

from netCDF4 import Dataset
import datetime
from ship_callsign import ship_callsign_list

VALID_EXTENSION = ['.nc', '.txt']
VALID_PROJECT = ['IMOS', 'FutureReefMap', 'SOOP-CO2_RT']
VESSEL_CODE = {'AA': 'VNAA',
               'IN': 'VLMJ'}  # Aurora Australis or Investigator


def ships():
    return ship_callsign_list()


def def_project(file):
    """
    # script deal with Realtime SOOP-CO2, Delayed Mode IMOS and Future_Reef_MAP files
    # eg : (DM) IMOS_SOOP-CO2_GST_20121027T045200Z_VLHJ_FV01.nc
    #      (DM) FutureReefMap_GST_20140530T185029Z_9V2768_FV01.nc
    #      <Project_Name>_<<Facility-Code>>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc
    #      (RT) IN_2017-165-0000dat.txt
           <Vessel_code>_yyyy-ddd-hhmmdat.txt
    """
    file_path, file_extension = os.path.splitext(file)
    file_basename = os.path.basename(file)
    file_parts = file_basename.split("_")

    assert file_extension in VALID_EXTENSION, "Invalid file extension '%s'. File should be .txt or .nc." % file_extension

    if file_basename.endswith('dat.txt'):  # file is RT data file
        project = 'SOOP-CO2_RT'
    elif file_extension == '.nc':
        project = file_parts[0]  # <Project-Name>
    else:
        sys.exit('File is either not a valid RT CO2 data file or not a netcdf.')
        return None

    return project


def soop_co2_rt_dest_path(file):
    """
    Generate destination path for RT file based on vessel_code
    eg:IN_2017-165-0000dat.txt
      <Vessel_code>_yyyy-ddd-hhmmdat.txt
    """
    file_basename = os.path.basename(file)
    file_parts = file_basename.split("_")

    project = 'IMOS'
    facility = 'SOOP'
    sub_facility = 'SOOP-CO2'
    data_type = 'Realtime'

    if file_parts[0] in VESSEL_CODE:
        code = VESSEL_CODE[file_parts[0]]
    else:
        sys.exit('Invalid vessel code. Aborting(=>soop_co2_rt_dest_path)')

    platform = code + "_" + ships()[code]

    year = int(file_parts[1][:4])
    jday = int(file_parts[1][5:8])
    if not (jday > 0 and jday <= 366) or not year >= 2017:
        sys.exit(
            'Failed extracting valid [year, day] from filename(=>soop_co2_rt_dest_path)')
        return None

    try:
        month = get_month_from_jday(jday, year)
    except:
        sys.exit('Could not determine month (=>soop_co2_rt_dest_path)')
        return None

    target_dir = os.path.join(project, facility,
                              sub_facility, platform,
                              data_type, str(year), str(month))
    return target_dir


def get_month_from_jday(jday, year):
    """
    Determine month from julian day (1-365). Leap year taken into account
    """
    # convert date (year + day) in gregorian ordinal day
    year_to_ordinal = datetime.date(year, 1, 1).toordinal() + jday - 1
    month = datetime.date.fromordinal(year_to_ordinal).month

    return month


def soop_co2_dest_path(file):
    """
    # eg : IMOS_SOOP-CO2_GST_20121027T045200Z_VLHJ_FV01.nc
    # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc
    """
    project = "IMOS"

    file_basename = os.path.basename(file)
    file_parts = file_basename.split("_")

    # the file name must have at least 6 component parts to be valid
    if len(file_parts) > 5:
        facility = file_parts[1]
        year = file_parts[3][:4]  # year out of <Start-date>

        # check for the code in the ships
        code = file_parts[4]
        if code in ships():
            platform = code + "_" + ships()[code]

            # open the file
            try:
                F = Dataset(file, mode='r')
            except:
                print >>sys.stderr, "Failed to open NetCDF file '%s'" % file
                return None
            # get cruise_id
            cruise_id = getattr(F, 'cruise_id', '')

            F.close()

            if not cruise_id:
                print >>sys.stderr, "File '%s' has no cruise_id attribute" % file
                return None

            target_dir = os.path.join(
                project, facility[:4], facility, platform, year, cruise_id)
            return target_dir

        else:
            print >>sys.stderr, "Hierarchy not created for '%s'" % file
            return None


def future_reef_map_dest_path(file):
    """
    # eg : FutureReefMap_GST_20140530T185029Z_9V2768_FV01.nc
    # <ProjectName>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc
    """
    project = "Future_Reef_MAP"
    data_type = "underway"
    file_basename = os.path.basename(file)
    file_parts = file_basename.split("_")

    # the file name must have at least 5 component parts to be valid
    if len(file_parts) > 4:

        year = file_parts[2][:4]  # year out of <Start-date>

        # check code in ships
        code = file_parts[3]

        if code in ships():
            platform = ships()[code]

        # open the file
        try:
            F = Dataset(file, mode='r')
        except:
            print >>sys.stderr, "Failed to open NetCDF file '%s'" % file
            return None
        # get cruise_id
        cruise_id = getattr(F, 'cruise_id', '')
        F.close()

        if not cruise_id:
            print >>sys.stderr, "File '%s' has no cruise_id attribute" % file
            return None

        target_dir = os.path.join(
            project, data_type, platform, year, cruise_id)
        return target_dir

    else:
        print >>sys.stderr, "Hierarchy not created for '%s'" % file
        return None


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    project = def_project(sys.argv[1])

    if project == 'IMOS':
        dest_path = soop_co2_dest_path(sys.argv[1])
    elif project == 'FutureReefMap':
        dest_path = future_reef_map_dest_path(sys.argv[1])
    else:  # project == 'SOOP-CO2 RT'
        dest_path = soop_co2_rt_dest_path(sys.argv[1])

    if not dest_path:
        exit(1)

    print dest_path
    exit(0)
