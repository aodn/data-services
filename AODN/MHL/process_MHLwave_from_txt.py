#! /usr/bin/env python
#! /usr/bin/autopep8
# Python module to process MHL SST mhl_sst_data

import os
import glob
import sys
from datetime import datetime, timedelta
import pytz
import pandas
import numpy as np
from netCDF4 import Dataset, date2num

from generate_netcdf_att import generate_netcdf_att

# module variables ###################################################
history_folder = '/vagrant/tmp/MHL/History'
output_folder = '/vagrant/tmp/MHL/output'
input_folder = '/vagrant/tmp/MHL/input'
site_list = {
    'BAT': ('WAVEBAB', 'Batemans Bay'),
    'BYR': ('WAVEBYB', 'Byron Bay'),
    'COF': ('WAVECOH', 'Coffs Harbour'),
    'CRH': ('WAVECRH', 'Crowdy Head'),
    'EDE': ('WAVEEDN', 'Eden'),
    'PTK': ('WAVEPOK', 'Port Kembla'),
    'SYD': ('WAVESYD', 'Sydney')}

# varlist = {
#    'VAVH': 'hsig',
#    'WMSH': 'hmean',  # initially called HMEAN
#    'HRMS': 'hrms',
#    'H10': 'h10',
#    'WMXH': 'hmax',  # initially called  HMAX
#    'TCREST': 'tc',
#    'VAVT': 'tz',
#    'TSIG': 'tsig',
#    'YRMS': 'yrms',
#    'WPPE': 'tP1',  # initially called TP1
#    ' TP2': 'tP2',
#      'M0': 'm0',
#    'VDIR': 'wdir'}
names_old = ['Date_Time', 'Hmean', 'Hrms', 'Hsig',
             'H10', 'Hmax', 'Tc', 'Tz', 'Tsig', 'Yrms',
             'TP1', 'TP2', 'M0', 'WDIR']
names_new = ['Date_Time', 'Hmean', 'Hrms', 'Hsig',
             'H10', 'Hmax', 'Tc', 'Tz', 'Tsig',
             'TP1', 'TP2', 'M0', 'Yrms', 'WDIR']
colspecs_old = [(0, 19), (22, 28), (30, 35), (37, 43),
                (45, 51), (52, 59), (63, 69), (71, 78), (80, 87),
                (88, 93), (96, 104), (107, 113), (113, 121), (126, 130)]
colspecs_new = [(0, 17), (26, 32), (39, 45), (52, 58),
                (64, 70), (77, 83), (88, 94), (99, 105), (112, 118),
                (125, 131), (137, 143), (147, 155), (162, 168), (183, 187)]
# functions #######################################################


def process_wave(txtfile):
    """
    Read mhl_wave_data from a CSV file (in current directory, unless
    otherwise specified) and convert it to a netCDF file.
    If successful, the name of the saved file is returned.
    """

    extension = txtfile[-4:]
    if extension == '.TXT':
        format = 'old'
        colspecs = colspecs_old
        header = 7
        skip_rows = 7
        names = names_old
    elif extension == '.txt':
        format = 'new'
        colspecs = colspecs_new
        header = 9
        skip_rows = 9
        names = names_new

    # CSV file to extract array of formatted data
    data = pandas.read_fwf(txtfile, colspecs=colspecs,
                           names=names, header=header, skip_rows=skip_rows)
    # convert time from string to decimal time, IMOS compliant
    (dtime, time) = convert_to_utc(data['Date_Time'], format)
    # use source filename to get deployment number.
    # extract spatial infor from summary  file
    site_code_short = os.path.basename(txtfile)[:3]
    spatial_data = get_spatial_data(txtfile, site_code_short, format)
    # generate NetCDF
    create_mhl_wave_ncfile(txtfile, site_code_short,
                           data, time, dtime, spatial_data)


def get_spatial_data(txtfile, site_code, format):
    """
    read in summary information about buoy
    input: txtfile
    output: numpy array of spatial info
    """
    # select the right summary_files information to open
    spatial_data_file_name = site_code + '_summ_history.csv'
    spatial_data_file = os.path.join(history_folder, spatial_data_file_name)
    spatial_info = pandas.read_csv(spatial_data_file, header=0)
    if format == 'old':
        deploy_n = os.path.basename(txtfile)[-6:-4]
    elif format == 'new':
        deploy_n = os.path.basename(txtfile).split('.')[0][-6:-4]

    return spatial_info.values[int(deploy_n) - 1]


def create_mhl_wave_ncfile(txtfile, site_code_short, data,
                           time, dtime, spatial_data):
    """
    create NetCDF file for MHL Wave data
    """
    site_code = site_list[site_code_short][0]
    netcdf_filename = create_netcdf_filename(site_code, data, dtime)
    netcdf_filepath = os.path.join(
        output_folder, "%s.nc") % netcdf_filename
    ncfile = Dataset(netcdf_filepath, "w", format="NETCDF4")

    # add IMOS1.4 global attributes and variable attributes stored in config
    # files
    config_file = os.path.join(os.getcwd(), 'global_att_wave.att')
    generate_netcdf_att(ncfile, config_file,
                        conf_file_point_of_truth=False)
    # Additional attribute either retrieved from original necdtf file
    # (if exists) or defined below
    original_netcdf_file_path = os.path.join(
        input_folder, "%s.nc") % netcdf_filename

    if os.path.exists(original_netcdf_file_path):
        # get glob attributes from original netcdf files.
        parse_nc_attribute(original_netcdf_file_path, ncfile)
    else:
        # generate site and deployment specific attributes
        ncfile.title = ("IMOS - ANMN New South Wales(NSW) %s"
                        "Offshore Wave Data (% s) -"
                        "Deployment No. %s %s to %s") % (
            site_list[site_code_short][1], site_code,
            spatial_data[0], min(dtime).strftime("%d-%m-%Y"),
            max(dtime).strftime("%d-%m-%Y"))
        ncfile.institution = 'Manly Hydraulics Laboratory'
        ncfile.keywords = ('Oceans | Ocean Waves |'
                           'Significant Wave Height, Oceans | Ocean Waves'
                           '| Wave Period, Oceans | Ocean Waves |'
                           'Wave Spectra, Oceans | Ocean Waves |'
                           'Wave Speed / direction')
        ncfile.principal_investigator = 'Mark Kulmar'
        ncfile.cdm_data_type = 'Station'
        ncfile.platform_code = site_code
        if site_code in ['WAVEPOK', 'WAVECOH', 'WAVECRH', 'WAVEEDN']:
            config_file = os.path.join(
                os.getcwd(), 'abstract_WAVE_default.att')
        elif site_code == 'WAVEBAB':
            config_file = os.path.join(os.getcwd(), 'abstract_WAVEBAB.att')
        elif site_code == 'WAVEBYB':
            config_file = os.path.join(os.getcwd(), 'abstract_WAVEBYB.att')
        else:  # WAVESYD
            config_file = os.path.join(os.getcwd(), 'abstract_WAVESYD.att')

        generate_netcdf_att(ncfile, config_file,
                            conf_file_point_of_truth=True)

    ncfile.sourceFilename = os.path.basename(txtfile)
    ncfile.date_created = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.time_coverage_start = min(dtime).strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.time_coverage_end = max(dtime).strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.geospatial_lat_min = spatial_data[1]
    ncfile.geospatial_lat_max = spatial_data[1]
    ncfile.geospatial_lon_min = spatial_data[2]
    ncfile.geospatial_lon_max = spatial_data[2]
    ncfile.geospatial_vertical_max = 0.
    ncfile.geospatial_vertical_min = 0.
    ncfile.deployment_number = int(spatial_data[0])

    # add dimension and variables
    ncfile.createDimension('TIME', len(time))

    TIME = ncfile.createVariable('TIME', "d", 'TIME')
    TIMESERIES = ncfile.createVariable('TIMESERIES', "i")
    LATITUDE = ncfile.createVariable(
        'LATITUDE', "d", fill_value=99999.)
    LONGITUDE = ncfile.createVariable(
        'LONGITUDE', "d", fill_value=99999.)
    WHTH = ncfile.createVariable('WHTH', "f", 'TIME', fill_value=99999.)
    WMSH = ncfile.createVariable('WMSH', "f", 'TIME', fill_value=99999.)
    HRMS = ncfile.createVariable('HRMS', "f", 'TIME', fill_value=99999.)
    WHTE = ncfile.createVariable('WHTE', "f", 'TIME', fill_value=99999.)
    WMXH = ncfile.createVariable('WMXH', "f", 'TIME', fill_value=99999.)
    TCREST = ncfile.createVariable('TCREST', "f", 'TIME', fill_value=99999.)
    VAVT = ncfile.createVariable('VAVT', "f", 'TIME', fill_value=99999.)
    WPTH = ncfile.createVariable('WPTH', "f", 'TIME', fill_value=99999.)
    YRMS = ncfile.createVariable('YRMS', "f", 'TIME', fill_value=99999.)
    WPPE = ncfile.createVariable('WPPE', "f", 'TIME', fill_value=99999.)
    TP2 = ncfile.createVariable('TP2', "f", 'TIME', fill_value=99999.)
    M0 = ncfile.createVariable('M0', "f", 'TIME', fill_value=99999.)
    VDIR = ncfile.createVariable('VDIR', "f", 'TIME', fill_value=99999.)

    # add global attributes and variable attributes stored in config files
    config_file = os.path.join(os.getcwd(), 'global_att_wave.att')
    generate_netcdf_att(ncfile, config_file,
                        conf_file_point_of_truth=True)

    # replace nans with fillvalue in dataframe
    data = data.fillna(value=float(99999.))

    TIME[:] = time
    TIMESERIES[:] = 1
    LATITUDE[:] = spatial_data[1]
    LONGITUDE[:] = spatial_data[2]
    WHTH[:] = data['Hsig'].values
    WMSH[:] = data['Hmean'].values
    HRMS[:] = data['Hrms'].values
    WHTE[:] = data['H10'].values
    WMXH[:] = data['Hmax'].values
    TCREST[:] = data['Tc'].values
    VAVT[:] = data['Tz'].values
    WPTH[:] = data['Tsig'].values
    YRMS[:] = data['Yrms'].values
    WPPE[:] = data['TP1'].values
    TP2[:] = data['TP2'].values
    M0[:] = data['M0'].values
    VDIR[:] = data['WDIR'].values

    ncfile.close()


def convert_to_utc(timestamp, format):
    """
    - Convert local timestamp to UTC without taking
    Daylight Saving Time into account. Fixed time difference of 10 hours
    - Then generate an array of timestamp converted to
     decimal time, IMOS format: days since 1950-01-01T00:00:00Z
     input: timestamp string '%d/%m/%Y %H:%M:%S'
           format : string  'old' or 'new'
     output:
     - time:array of decimal time from 1950-01-01T00:00:00Z
     - dtime: array of datetime object
    """
    epoch = datetime(1950, 1, 1)
    time = []
    dtime = []
    for t in timestamp:
        if format == 'old':
            dt = datetime.strptime(t, '%d/%m/%Y %H:%M:%S')
        elif format == 'new':
            assert type(t) is str, pdb.set_trace()
            dt = datetime.strptime(t, '%d-%b-%Y %H:%M')

        dt = dt - timedelta(hours=10)
        dtime.append(dt)
        time.append((dt - epoch).total_seconds())

    time = np.array(time) / 3600. / 24.
    dtime = np.array(dtime)
    return (dtime, time)


def create_netcdf_filename(site_code, data_array, dtime):
    """
    Create IMOS compliant filename
    """
    start_date = dtime[0].strftime('%Y%m%dT%H%M%SZ')
    end_date = dtime[-1].strftime('%Y%m%dT%H%M%SZ')
    return "IMOS_ANMN-NSW_W_%s_%s_FV01_END-%s" % (
        start_date, site_code, end_date)


def parse_nc_attribute(input_netcdf_file_path, output_nc_obj):
    """
    Read in attributes from a netcdf filename
    and return attribute
    gatts, data, annex = parse_nc_attribute(netcdf_file_path)
    """
    print "reading attributes from %s" % input_netcdf_file_path
    input_nc_obj = Dataset(
        input_netcdf_file_path, 'r', format='NETCDF3_CLASSIC')
    output_nc_obj.title = input_nc_obj.title
    output_nc_obj.institution = input_nc_obj.dataContact_organisationName
    output_nc_obj.abstract = input_nc_obj.abstract
    output_nc_obj.keywords = input_nc_obj.keywords
    output_nc_obj.principal_investigator = (input_nc_obj.
                                            principal_investigator)
    output_nc_obj.cdm_data_type = input_nc_obj.cdm_data_type
    output_nc_obj.platform_code = input_nc_obj.platform_code
    output_nc_obj.comment = input_nc_obj.metadataDataQualityLineage

    input_nc_obj.close()


if __name__ == '__main__':


    for txtfile in glob.glob('/vagrant/tmp/MHL/TXTFILES/*.TXT'):
        print "processing : %s" % txtfile
        data = process_wave(txtfile)
