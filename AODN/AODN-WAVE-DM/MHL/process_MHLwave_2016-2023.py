#! /usr/bin/env python
# ! /usr/bin/autopep8
# Python module to process MHL SST mhl_sst_data

import os

import argparse
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from netCDF4 import Dataset, date2num
from lib.python.generate_netcdf_att import generate_netcdf_att

# module variables ###################################################
history_folder = '/home/bpasquer/github_repo/chef/tmp/MHL/history'
output_folder = '//home/bpasquer/github_repo/chef/tmp/MHL/output'
input_folder = '/home/bpasquer/github_repo/chef/tmp/MHL/input'
workingdir = '/home/bpasquer/github_repo/chef/src/data-services/MHL'
site_list = {
    'BAT': ('WAVEBAB', 'Batemans Bay'),
    'BYR': ('WAVEBYB', 'Byron Bay'),
    'COF': ('WAVECOH', 'Coffs Harbour'),
    'CRH': ('WAVECRH', 'Crowdy Head'),
    'EDE': ('WAVEEDN', 'Eden'),
    'PTK': ('WAVEPOK', 'Port Kembla'),
    'SYD': ('WAVESYD', 'Sydney')}

Mapped_varlist = {
   'WHTH': 'Hsig',
   'WMXH': 'Hmax',
   'WPMH': 'Tz',
   'WPTH': 'Tsig',
   'WPPE': 'TP1',
   'TP2': 'TP2',
   'WPDI': 'WDIR'}

varnames = ['Date/Time', 'Hmean', 'Hrms', 'Hsig',
            'H10', 'Hmax', 'Tc', 'Tz', 'Tsig',
            'TP1', 'TP2', 'M0', 'Yrms', 'WDIR']


# functions #######################################################


def process_wave(file, site_name):
    """
    Read mhl_wave_data from a CSV file (in current directory, unless
    otherwise specified) and convert it to a netCDF file.
    If successful, the name of the saved file is returned.
    """
    # CSV file to extract array of formatted data
    df = pd.read_csv(file, names=varnames, header=8, skiprows=[8], index_col=False)
    # convert time from string to decimal time, IMOS compliant
    (dtime, time) = convert_to_utc(df['Date/Time'], '%d/%m/%Y %H:%M')

    # use source filename to get deployment number.
    # extract metadata from summary  file
    deploy_all = get_deployment_metadata(file, site_name)
    # determine if data needs spliting across multiple deployments
    deployment = set_buoy_coord(df, deploy_all, dtime)

    for i in range(0, len(deployment)):
        netcdf_filename = create_netcdf_filename(site_name, deployment.loc[i])
        netcdf_filepath = os.path.join(
            output_folder, "%s.nc") % netcdf_filename
        ncfile = Dataset(netcdf_filepath, "w", format="NETCDF4")
        create_ncfile(file,ncfile, site_name,
                           df, time, dtime, deployment.loc[i])


def set_buoy_coord(df, deploy_df, dtime):
    # set coord for each point in df based on location history
    # find deployments metadata
    #create and assign df column{Latitude][Longitude] with correct values

    n_deploy = deploy_df['end_date'] > datetime.strptime('2016-01-01 00', "%Y-%m-%d %H")
    idx = deploy_df.index[n_deploy]
    deployments = deploy_df.loc[idx]
    #reset start date of deployment encompassing '2016-01-01'
    deployments.loc[idx[0],('start_date')] = pd.to_datetime('2016-01-01 00:00') - timedelta(hours=10)

    if len(idx) ==1:# same deployment since 2016
        df['latitude'] = deploy_df['latitude'][[idx[0]]]
        df['longitude'] = deploy_df['longitude'][[idx[0]]]
        deployments.index = [0]  #reindex
    # assign values if 2 deployments
    elif len(idx)==2:
        for i in range(1, len(idx)):
            df['latitude'] = np.where(dtime > deployments['end_date'][idx[i-1]], deploy_df['latitude'][[idx[i]]],
                                      deploy_df['latitude'][[idx[i-1]]])
            df['longitude'] = np.where(dtime > deployments['end_date'][idx[i-1]], deploy_df['longitude'][[idx[i]]],
                                  deploy_df['longitude'][[idx[i - 1]]])
        deployments.index = [0, 1]

    return deployments

def get_deployment_metadata(file, site_name):
    """
    read in summary information about buoy
    input: csvfile
    output: dataframe spatial info
    """
    # select the right summary_files information to open
    spatial_data_file_name = site_name + '.csv'
    spatial_data_file = os.path.join(history_folder, spatial_data_file_name)
    spatial_info = pd.read_csv(spatial_data_file, header=7, skiprows=[8])

    deploy_n = spatial_info['Location']
    start_time = spatial_info['1st Nomtime'].dropna().astype(int).astype(str)
    end_time = spatial_info['Last Nomtime'].dropna().astype(int).astype(str)
    start_time_utc = pd.DataFrame(convert_to_utc(start_time, '%Y%m%d%H')[0])
    end_time_utc = pd.DataFrame(convert_to_utc(end_time, '%Y%m%d%H')[0])
    latitude = spatial_info['Latitude.1'].dropna()
    longitude = spatial_info['Longitude.1'].dropna()

    df = pd.concat([deploy_n, start_time_utc, end_time_utc, latitude, longitude], axis=1)
    df.columns = ['deploy_n', 'start_date', 'end_date', 'latitude', 'longitude']
    df.drop(15, inplace=True)

    return df

def create_ncfile(file, ncfile, site_name, data,
                           time, dtime, metadata):
    """
    create NetCDF file for MHL Wave data
    """
    # add IMOS1.4 global attributes and variable attributes stored in config
    # files
    config_file = os.path.join(os.getcwd(), 'mhl_wave_library', 'global_att_wave.att')
    generate_netcdf_att(ncfile, config_file,
                               conf_file_point_of_truth=False)

    # generate site and deployment specific attributes
    ncfile.title = (" New South Wales Manly Hydraulics Laboratory %s"
                    "Offshore Wave Data -"
                    "Deployment No. %s %s to %s") % (
                       site_name,
                       metadata['deploy_n'],  metadata['start_date'].strftime("%d-%m-%Y"),
                       metadata['end_date'].strftime("%d-%m-%Y"))
    ncfile.institution = 'Manly Hydraulics Laboratory'
    ncfile.principal_investigator = 'Matt Phillips, Megan Liu'
    ncfile.cdm_data_type = 'Station'
    ncfile.site_name = site_name
    config_file = os.path.join(os.getcwd(), 'common', 'abstract_WAVE_default.att')

    # generate_netcdf_att(ncfile, config_file,
    #                            conf_file_point_of_truth=False)

    ncfile.sourceFilename = os.path.basename(file)
    ncfile.date_created = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.time_coverage_start = metadata['start_date'].strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.time_coverage_end = metadata['end_date'].strftime("%Y-%m-%dT%H:%M:%SZ")
    ncfile.geospatial_lat_min = metadata['latitude']
    ncfile.geospatial_lat_max = metadata['latitude']
    ncfile.geospatial_lon_min = metadata['longitude']
    ncfile.geospatial_lon_max = metadata['longitude']
    ncfile.geospatial_vertical_max = 0.
    ncfile.geospatial_vertical_min = 0.

    # add dimension and variables
    #if multiple dployments, need to find last index(for 1st deployment) of firts index(for last dployment)
    first = np.where(dtime < metadata['start_date'])
    if len(first[0])!=0:
        firstindx = first[0][-1]+1
        ntime = len(dtime) - firstindx
        cond = True
    else:
        pass
    # find index of last time for deployment:
    last = np.where(dtime > metadata['end_date'])
    if len(last[0])!=0:
        lastindx = last[0][0]-1
        ntime = lastindx
        cond = False
    else:
        pass

    ncfile.createDimension('TIME', ntime)

    TIME = ncfile.createVariable('TIME', "d", 'TIME')
    timeSeries = ncfile.createVariable('TIMESERIES', "i")
    LATITUDE = ncfile.createVariable('LATITUDE', "d", 'TIME',  fill_value=99999.)
    LONGITUDE = ncfile.createVariable('LONGITUDE', "d", 'TIME',  fill_value=99999.)

    for var in Mapped_varlist:
       ncfile.createVariable(var, np.dtype('f'), 'TIME', fill_value=99999.)

    WAVE_quality_control = ncfile.createVariable("WAVE_quality_control", "b", "TIME", fill_value=np.int8(-127))

    # add global attributes and variable attributes stored in config files
    config_file = os.path.join(os.getcwd(), 'mhl_wave_library', 'global_att_wave.att')
    generate_netcdf_att(ncfile, config_file,
                               conf_file_point_of_truth=True)
    if cond:
        datarange = range(firstindx, len(dtime))
    else:
        datarange = range(0, lastindx)

    TIME[:] = time[datarange]
    timeSeries[:] = 1
    LATITUDE[:] = data['latitude'].values[datarange]
    LONGITUDE[:] = data['longitude'].values[datarange]
    for nc_var in Mapped_varlist:
        ncfile[nc_var][:] = data[Mapped_varlist[nc_var]].values[datarange]
        # nc_var.valid_max = np.float32(nc_var.valid_max)
        # nc_var.valid_min = np.float32(nc_var.valid_min)

    # set QC flag values
    qc_flag = [1 for i in range(0, ntime)]
    flag_values = [1, 2, 3, 4, 9]
    setattr(ncfile['WAVE_quality_control'], 'flag_values', np.int8(flag_values))
    WAVE_quality_control[:] = np.int8(qc_flag)

    ncfile.close()


def convert_to_utc(timestamp, format):
    """
    - Convert local timestamp to UTC without taking
    Daylight Saving Time into account. Fixed time difference of 10 hours
    - Then generate an array of timestamp converted to
     decimal time, IMOS format: days since 1950-01-01T00:00:00Z
     input: timestamp string
            timestamp format
     output:
     - time:array of decimal time from 1950-01-01T00:00:00Z
     - dtime: array of datetime object
    """
    epoch = datetime(1950, 1, 1)
    time = []
    dtime = []
    for t in timestamp:
        dt = datetime.strptime(t, format)
        dt = dt - timedelta(hours=10)
        dtime.append(dt)
        time.append((dt - epoch).total_seconds())

    time = np.array(time) / 3600. / 24.
    dtime = np.array(dtime)
    return (dtime, time)


def create_netcdf_filename(site_name, deploy):
    """
    Create IMOS compliant filename
    """
    start_date = deploy['start_date'].strftime('%Y%m%d')
    end_date = deploy['end_date'].strftime('%Y%m%d')
    return "MHL_%s_%s_DM_WAVE-PARAMETERS_END-%s" % (
        start_date, str.upper(site_name).replace(' ', '-'), end_date)


def parse_nc_attribute(input_netcdf_file_path, output_nc_obj):
    """
    Read in attributes from a netcdf filename
    and return attribute
    gatts, data, annex = parse_nc_attribute(netcdf_file_path)
    """
    print("reading attributes from %s" % input_netcdf_file_path)
    input_nc_obj = Dataset(input_netcdf_file_path, 'r', format='NETCDF3_CLASSIC')

    input_nc_obj.close()


if __name__ == '__main__':

    """
    Input path of text files
    input: text file *.TXT or *_new.txt
    ex: ./process_MHLwave_from_txt.py  "/vagrant/tmp/MHL/TXTFILES/"
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('dir_path', help="Full path to input text file directory")

    args = parser.parse_args()
    dir_path = args.dir_path
    for file in os.listdir(dir_path):
        print("processing : %s" % file)
        site_name = file.split('_')[0]
        data = process_wave(os.path.join(dir_path, file), site_name)
