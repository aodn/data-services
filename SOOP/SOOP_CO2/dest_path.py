#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

from netCDF4 import Dataset

from ship_callsign import ship_callsign_list


def ships():
    return ship_callsign_list()

def def_project(nc_file):
    """
    # script deal with either IMOS or Future_Reef_MAP project files
    # eg : IMOS_SOOP-CO2_GST_20121027T045200Z_VLHJ_FV01.nc
    # eg : FutureReefMap_GST_20140530T185029Z_9V2768_FV01.nc
    # <Project_Name>_<<Facility-Code>>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc
    """
    nc_file_basename = os.path.basename(nc_file)
    file = nc_file_basename.split("_")

    project = file[0] # <Project-Name>
    return project

def soop_co2_dest_path(nc_file):
    """
    # eg : IMOS_SOOP-CO2_GST_20121027T045200Z_VLHJ_FV01.nc
    # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc
    """
    project = "IMOS"

    nc_file_basename = os.path.basename(nc_file)
    file             = nc_file_basename.split("_")

    # the file name must have at least 6 component parts to be valid
    if len(file) > 5:
        facility = file[1]
        year     = file[3][:4] # year out of <Start-date>

        # check for the code in the ships
        code = file[4]
        if code in ships():
            platform = code + "_" + ships()[code]

            # open the file
            try:
                F = Dataset(nc_file, mode='r')
            except:
                print >>sys.stderr, "Failed to open NetCDF file '%s'" % nc_file
                return None
            # get cruise_id
            cruise_id = getattr (F, 'cruise_id', '')

            F.close()

            if not cruise_id:
                print >>sys.stderr, "File '%s' has no cruise_id attribute" % nc_file
                return None

            target_dir = os.path.join(project, facility[:4], facility, platform, year, cruise_id)
            return target_dir

        else:
            print >>sys.stderr, "Hierarchy not created for '%s'" % nc_file
            return None


def future_reef_map_dest_path(nc_file):
    """
    # eg : FutureReefMap_GST_20140530T185029Z_9V2768_FV01.nc
    # <ProjectName>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>.nc
    """
    project          = "Future_Reef_MAP"
    data_type        = "underway"
    nc_file_basename = os.path.basename(nc_file)
    file             = nc_file_basename.split("_")

    # the file name must have at least 5 component parts to be valid
    if len(file) > 4:

        year = file[2][:4] # year out of <Start-date>

        # check code in ships
        code = file[3]

        if code in ships():
            platform = ships()[code]

        # open the file
        try:
            F = Dataset(nc_file, mode='r')
        except:
            print >>sys.stderr, "Failed to open NetCDF file '%s'" % nc_file
            return None
        # get cruise_id
        cruise_id = getattr (F, 'cruise_id', '')
        F.close()

        if not cruise_id:
            print >>sys.stderr, "File '%s' has no cruise_id attribute" % nc_file
            return None

        target_dir = os.path.join(project, data_type, platform, year, cruise_id)
        return target_dir

    else:
        print >>sys.stderr, "Hierarchy not created for '%s'" % nc_file
        return None


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    project = def_project(sys.argv[1])

    if project == 'IMOS':
        dest_path = soop_co2_dest_path(sys.argv[1])
    elif project == 'FutureReefMap':
        dest_path = future_reef_map_dest_path(sys.argv[1])
    else:
        exit(1)

    if not dest_path:
        exit(1)

    print dest_path
    exit(0)
