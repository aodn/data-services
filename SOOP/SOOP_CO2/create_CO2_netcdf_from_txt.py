#! /usr/bin/env python
# Script for automated generation of NetCDF file storing realtime SOOP-CO2 data.
# Script processes data from 2 vessels: RV Aurora Australis and RV Investigator
# -Exctract varaiable relevant to CO2 measurements and processing from input text file.
# -Map vessel specific variable to set of common output variables
# Mapping as follows:
#       Input Variable                  NetCDF Variable
#   Aurora      Investigator
#       PcDate+PcTime                        TIME
#       GpsShipLatitude                     LATITUDE
#       GpsShipLongitude                    LONGITUDE
#           Type                            TYPE
#           EquTemp                         TEQ_raw
#           CO2StdValue                     CO2_STD_Value
#           CO2um_m                         xCO2_PPM_raw
#           H2Omm_m                         H2O_mm_m_raw
#       DryBoxDruckPress                    Press_Licor_raw
#           EquPress                        Press_Equil_raw
#           EquH2OFlow                      H2O_flow_raw
#           LicorFlow                       Licor_flow_raw
#           AtmSeaLevelPress                ATMP_raw
#           MetTrueWindSpKts                WSPD_raw
#           MetTrueWindDir                  WDIR_raw
#           IntakeShipTemp                  TEMP_raw
# TsgSbe45Salinity  TsgShipSalinity          PSAL_raw
# TsgSbe45Temp      TsgShipTemp             TEMP_Tsg_raw
# SBE45Flow         TsgShipFlow             Tsg_flow_raw
#    -             LabMainSwFlow            LabMain_sw_flow_raw

import os
import sys
from datetime import datetime
import pandas as pd
import numpy as np
from netCDF4 import Dataset, stringtochar
import re
import collections
from generate_netcdf_att import generate_netcdf_att

from ship_callsign import ship_callsign_list as ships

INPUT_RT_PARAMETERS = {'Type', 'PcDate', 'PcTime', 'GpsShipLatitude',
                       'GpsShipLongitude', 'EquTemp', 'CO2StdValue',
                       'CO2um_m', 'H2Omm_m', 'DryBoxDruckPress', 'EquPress',
                       'EquH2OFlow', 'LicorFlow', 'IntakeShipTemp', 'MetTrueWindSpKts',
                       'MetTrueWindDir', 'AtmSeaLevelPress'}
AA_SPECIFIC_INPUT_PARAMS = {'SBE45Flow', 'TsgSbe45Temp',
                            'TsgSbe45Salinity'}
IN_SPECIFIC_INPUT_PARAMS = {'TsgShipTemp',
                            'TsgShipSalinity', 'TsgShipFlow', 'LabMainSwFlow'}

VESSEL = {
    'AA': 'VNAA',
    'IN': 'VLMJ'}


def process_co2_rt(txtfile):
    """
    Read in data from co2 realtime file and produce a netcdf file
    """
    # Parse data into dataframe
    (dataf, platform_code) = read_realtime_file(txtfile)
    # format data
    (dtime, time) = get_time_formatted(dataf)
    # generate nc file name
    netcdf_filename = create_netcdf_filename(platform_code, dtime)

    netcdf_file_path = os.path.join(
        os.getenv('WIP_DIR'), 'SOOP', 'SOOP_CO2', "%s.nc") % netcdf_filename

    create_netcdf(netcdf_file_path, dataf, dtime, time, txtfile, platform_code)

    return netcdf_file_path


def create_netcdf_filename(platform_code, dtime):
    """
    Generate filename
    """
    facility_param = 'IMOS_SOOP-CO2_GST_'
    prodtype = '_FV00_END-'
    time_start = min(dtime).strftime("%Y%m%dT%H%M%SZ")
    time_end = max(dtime).strftime("%Y%m%dT%H%M%SZ")
    filename = facility_param + time_start + \
        '_' + platform_code + prodtype + time_end

    return filename


def get_time_formatted(dataf):
    """
    Convert date and time data object into datetime
    Input : data Frame
    Return:
         - time:array of decimal time from 1950-01-01T00:00:00
         - dtime: array of datetime object
    """
    epoch = datetime(1950, 1, 1)
    time = []
    time_long = dataf['PcDate'].values + ' ' + dataf['PcTime'].values
    dtime = pd.to_datetime(time_long, dayfirst=True, utc=True)
    for t in dtime:
        dt = datetime.strptime(datetime.strftime(
            t, '%d/%m/%Y %H:%M:%S'), '%d/%m/%Y %H:%M:%S')
        time.append((dt - epoch).total_seconds())

    time = np.array(time) / 3600. / 24.

    return(dtime, time)


def create_netcdf(netcdf_file_path, dataf, dtime, time, txtfile, platform_code):
    """
    Create a netcdf file
    """
    ncfile = Dataset(netcdf_file_path, "w", format="NETCDF4")
    config_file = os.path.join(
        os.getenv('DATA_SERVICES_DIR'), 'SOOP', 'SOOP_CO2', 'global_att_soop_co2.att')

    if platform_code in ships():
        vessel_name = ships()[platform_code]
    else:
        sys.exit("Unknow ship code '%s' from '%s' ") % netcdf_file_path

    # generate voyage specific attributes
    ncfile.title = ("IMOS SOOP Underway CO2 dataset measured onboard the %s "
                    "between the %s and %s") % (
        vessel_name,
        min(dtime).strftime(
            "%d-%b-%Y %H:%M:%S"),
        max(dtime).strftime("%d-%b-%Y %H:%M:%S"))
    ncfile.date_created = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.abstract = (" This dataset contains underway CO2 measurements collected onboard the %s "
                       "between the %s and %s") % (vessel_name,
                                                   min(dtime).strftime(
                                                       "%d-%b-%Y %H:%M:%S"),
                                                   max(dtime).strftime("%d-%b-%Y %H:%M:%S"))

    ncfile.time_coverage_start = min(dtime).strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.time_coverage_end = max(dtime).strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.geospatial_lat_min = min(pd.to_numeric(dataf['GpsShipLatitude']))
    ncfile.geospatial_lat_max = max(pd.to_numeric(dataf['GpsShipLatitude']))
    ncfile.geospatial_lon_min = min(pd.to_numeric(dataf['GpsShipLongitude']))
    ncfile.geospatial_lon_max = max(pd.to_numeric(dataf['GpsShipLongitude']))
    ncfile.geospatial_vertical_min = 0.
    ncfile.geospatial_vertical_max = 0.
    ncfile.vessel_name = vessel_name
    ncfile.platform_code = platform_code

    ncfile.sourceFilename = os.path.basename(txtfile)

    # add dimension and variables
    string_9_dim = 9  # max length of string TYPE across platform
    ncfile.createDimension('TIME', len(time))
    ncfile.createDimension('string_9', string_9_dim)
    # Choose to use PCtime /Date for TIME variable
    TIME = ncfile.createVariable('TIME', "d", 'TIME')
    LATITUDE = ncfile.createVariable('LATITUDE', "d", 'TIME', fill_value=-999.)
    LONGITUDE = ncfile.createVariable(
        'LONGITUDE', "d", 'TIME', fill_value=-999.)
    TYPE = ncfile.createVariable('TYPE', 'S1', ('TIME', 'string_9'))
    TEQ_raw = ncfile.createVariable('TEQ_raw', "f", 'TIME', fill_value=-999.)
    CO2_STD_Value = ncfile.createVariable(
        'CO2_STD_Value', "f", 'TIME', fill_value=-999.)
    xCO2_PPM_raw = ncfile.createVariable(
        'xCO2_PPM_raw', "f", 'TIME', fill_value=-999.)
    H2O_mm_m_raw = ncfile.createVariable(
        'H2O_mm_m_raw', "f", 'TIME', fill_value=-999.)
    # Need to use DryBoxdruck Pressure instead of LicorPress
    Press_Licor_raw = ncfile.createVariable(
        'Press_Licor_raw', "f", 'TIME', fill_value=-999.)
    Press_Equil_raw = ncfile.createVariable(
        'Press_Equil_raw', "f", 'TIME', fill_value=-999.)
    H2O_flow_raw = ncfile.createVariable(
        'H2O_flow_raw', "f", 'TIME', fill_value=-999.)
    Licor_flow_raw = ncfile.createVariable(
        'Licor_flow_raw', "f", 'TIME', fill_value=-999.)
    TEMP_raw = ncfile.createVariable(
        'TEMP_raw', "f", 'TIME', fill_value=-999.)     # IntakeShipTemp
    PSAL_raw = ncfile.createVariable('PSAL_raw', "f", 'TIME', fill_value=-999.)
    ATMP_raw = ncfile.createVariable('ATMP_raw', "f", 'TIME', fill_value=-999.)
    WSPD_raw = ncfile.createVariable('WSPD_raw', "f", 'TIME', fill_value=-999.)  # MetTrueWindSpKts
    WDIR_raw = ncfile.createVariable('WDIR_raw', "f", 'TIME', fill_value=-999.)  # MetTrueWindDir
    Tsg_flow_raw = ncfile.createVariable(
            'Tsg_flow_raw', "f", 'TIME', fill_value=-999.)
    TEMP_Tsg_raw = ncfile.createVariable(
        'TEMP_Tsg_raw', "f", 'TIME', fill_value=-999.)

    if platform_code == 'VLMJ':
        LabMain_sw_flow_raw = ncfile.createVariable(
            'LabMain_sw_flow_raw', "f", 'TIME', fill_value=-999.)

    # add IMOS standard global attributes and variable attributes
    generate_netcdf_att(ncfile, config_file, conf_file_point_of_truth=True)
    # set attribute value to variable type

    for nc_var in [TEQ_raw, PSAL_raw, TEMP_raw, TEMP_Tsg_raw]:
        nc_var.valid_max = np.float32(nc_var.valid_max)
        nc_var.valid_min = np.float32(nc_var.valid_min)

    # convert Wind speed to ms-1 before filling array with fillvalue
    dataf['MetTrueWindSpKts'] = dataf['MetTrueWindSpKts'].multiply(0.514444)

    # replace nans with fillvalue in dataframe
    dataf.fillna(value=float(-999.), inplace=True)
    # Can use either PCDate/Time or GPS. Decided to use PCDate /Time as it
    # simplifies the code
    TIME[:] = time

    LATITUDE[:] = dataf['GpsShipLatitude'].values
    LONGITUDE[:] = dataf['GpsShipLongitude'].values

    # create fixed length strings padded with space
    # create variable of type string, then convert to array of char
    type_tmp = []

    for id in range(len(dataf['Type'])):
        type_tmp.append(dataf['Type'][id].ljust(string_9_dim))

    # convert to array of char
    type_tmp = stringtochar(np.array(type_tmp))
    TYPE[:] = type_tmp
    TEQ_raw[:] = dataf['EquTemp'].values
    CO2_STD_Value[:] = dataf['CO2StdValue'].values
    xCO2_PPM_raw[:] = dataf['CO2um_m'].values
    H2O_mm_m_raw[:] = dataf['H2Omm_m'].values
    Press_Licor_raw[:] = dataf['DryBoxDruckPress'].values
    Press_Equil_raw[:] = dataf['EquPress'].values
    H2O_flow_raw[:] = dataf['EquH2OFlow'].values
    Licor_flow_raw[:] = dataf['LicorFlow'].values
    TEMP_raw[:] = dataf['IntakeShipTemp'].values
    # WSP converted to m s-1
    WSPD_raw[:] = dataf['MetTrueWindSpKts'].values
    WDIR_raw[:] = dataf['MetTrueWindDir'].values
    ATMP_raw[:] = dataf['AtmSeaLevelPress'].values

    if platform_code == 'VLMJ':
        TEMP_Tsg_raw = dataf['TsgShipTemp'].values
    #        Tsg_flow_raw = dataf['TsgShipFlow'].values
        LabMain_Sw_flow_raw = dataf['LabMainSwFlow'].values
        PSAL_raw[:] = dataf['TsgShipSalinity'].values
    elif platform_code == 'VNAA':
        TEMP_Tsg_raw[:] = dataf['TsgSbe45Temp'].values
        PSAL_raw[:] = dataf['TsgSbe45Salinity'].values
    #        Tsg_flow_raw[:] = dataf['SBE45Flow'].values

    ncfile.close()


def read_realtime_file(rt_file):
    """
    Reads in data from realtime text files
    Cause input files have inconsistent number of column per line
    the function first reads file line by line into list, then create data frame
    Returns  : dataframe
               vessel_code_short
    """
    data = []

    file_basename = os.path.basename(rt_file)

    # check that vessel specific prefix is valid
    platform_code_short = file_basename[0:2]
    assert platform_code_short in VESSEL, "File name '%s' has unknown vessel_code" % rt_file
    platform_code = VESSEL[platform_code_short]

    with open(rt_file, 'r') as f:
        header_txt_file = f.readline()
        header_txt_file = (re.split(r'\t+', header_txt_file.rstrip('\r\n')))

        # create  an ordered dictionary of paramter name:indices
        headers = [(header_col, header_txt_file.index(header_col))
                   for header_col in header_txt_file]
        input_rt_parameter = collections.OrderedDict(headers)

        for line in f:
            tmp_line = re.split(r'\t+', line.rstrip('\r\n'))
            if len(tmp_line) == len(input_rt_parameter):
                data.append(tmp_line)
            elif len(tmp_line) > 5 and len(tmp_line) < len(input_rt_parameter):
                line_filled_w_nans = fill_missing_with_nan(line.rstrip('\r\n'))
                line_filled_w_nans = re.split(r'\t+', line_filled_w_nans)
                data.append(line_filled_w_nans)
            else:
                continue

    # Convert list into array
    data_array = np.asarray(data)

    # array into dataframe
    dataf = pd.DataFrame(data_array, columns=input_rt_parameter.keys())
    # check parameters
    dataf = check_parameters(dataf, platform_code_short,
                             input_rt_parameter, rt_file)

    return dataf, platform_code


def fill_missing_with_nan(line):
    """
    Solve issue with timesteps containing missing fields (case in Aurora files)
    Loop through occurences of matched pattern (here consisting of 2 consecutive tabs)
    and insert NaN between consecutive tabs. Since re.search looks for first location of pattern)
    insert, function iterate until expression does not produce a match
    """
    while re.search(r'\t\t', line) is not None:
        m = re.search(r'\t\t', line)
        re.sub(r'\t\t', line[:m.start() + 1] +
               'NaN' + line[m.end() - 1:], line)
        line = line[:m.start() + 1] + 'NaN' + line[m.end() - 1:]

    return line


def check_parameters(dataf, vessel_code, input_param, rt_file):
    """
    Checks parameters list contains all required parameter(vessel specific)
    Cast selected parameter data to correct type
    Returns dupdated dataframe
    """
    rt_input_parameters = set.union(INPUT_RT_PARAMETERS,
                                    eval(vessel_code + '_SPECIFIC_INPUT_PARAMS'))
    if not all(param in input_param for param in rt_input_parameters):
        missing_param = []
        for required_param in rt_input_parameters:
            if required_param not in input_param:
                missing_param = missing_param.append(required_param)
                sys.exit("Missing parameter(s) '{missing_param}' in file '{rt_file}'.Aborting".format(
                    missing_param=missing_param, rt_file=rt_file))
    else:  # required_param all present . Change dtype to numeric where relevant
         # var TYPE conversion to string outside this function
        for param in rt_input_parameters:
            if param not in set(['Type', 'PcDate', 'PcTime']):
                dataf[param] = dataf[param].apply(pd.to_numeric, errors=coerce)

    return dataf


if __name__ == '__main__':
    try:
        input_file = sys.argv[1]
    except IndexError:
        sys.exit("usage: {script} RT_FILE".format(script=sys.argv[0]))

    netcdf_file = process_co2_rt(input_file)

    if not netcdf_file:
        exit(1)

    print netcdf_file
    exit(0)
