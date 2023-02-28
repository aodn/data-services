#!/usr/bin/env python3
import argparse
import sys
import glob

import os
import json
import pandas as pd
import numpy as np
import datetime
import re
import tempfile
from netCDF4 import date2num
from jsonmerge import merge

from aodntools.ncwriter import ImosTemplate


CONFIG_DIR = os.path.join(os.getcwd(), 'bom_triaxys_library')
SITE_METADATA = 'site_metadata.json'
VARIABLE_LOOKUP = 'variables_lookup.json'
TEMPLATE = 'template_bom.json'

HEADER_2019 = {'regex': '.*2019_AXYS_Listing.csv$',
              'skiprows': [0, 1, 2, 3, 4, 5, 6, 8]}
HEADER_2020 = {'regex': '.*2020_AXYS_Listing.csv$',
              'skiprows': [0, 1, 2, 3, 4, 5, 6, 7, 9]}
HEADER_2021 = {'regex': '.*2021_AXYS_Listing.csv$',
              'skiprows': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12]}

DATA_COLUMNS = [0, 3, 4, 5, 6, 8, 9, 10, 12, 13, 14]

def get_data(file, sitecode, format):
    # extract data from csv in a dataframe
    df = pd.read_csv(file, skiprows=format['skiprows'],
                     usecols=DATA_COLUMNS, parse_dates=[0])

    variable_lookup = read_json_config(os.path.join(CONFIG_DIR, VARIABLE_LOOKUP))

    for key, value in variable_lookup.items():
        df.rename(columns={key: value}, inplace=True)

    # convert time to timestamp
    df['TIME'] = pd.to_datetime(df['TIME'], utc=True)
    # generate Latitude, longitude and wave_quality_control and timeSeries dataset
    data_shape = df.shape
    # WAVE  QC -only good data
    filldata_qc = np.full(data_shape[0], 1)
    df['WAVE_quality_control'] = filldata_qc.astype(np.int8)
    # LAT &LON

    site_metadata = read_json_config(os.path.join(CONFIG_DIR, SITE_METADATA))
    for var in ['LATITUDE', 'LONGITUDE']:
        filldata_coor = np.full(data_shape[0], site_metadata['sites'][sitecode][var.lower()])
        df[var] = filldata_coor.astype(float)

    return df


def read_json_config(path):
    with open(path) as f:
        json_obj = json.load(f)

    f.close()
    return json_obj


def merge_metadata_json(sitecode):
    # merge bom_template with site specific metadata

    all_site_metadata = read_json_config(os.path.join(CONFIG_DIR, SITE_METADATA))
    bom_template = read_json_config(os.path.join(CONFIG_DIR, TEMPLATE))
    site_metadata = all_site_metadata['sites'][sitecode]
    merge_json = merge(bom_template, site_metadata)

    json_tmp_file = tempfile.mktemp()
    with open(json_tmp_file, "w") as file:
        json.dump(merge_json, file, indent=2, sort_keys=True)

    return json_tmp_file


def generate_netcdf(df, sitecode, output_path):
    # generate netcdf file

    merged_template = merge_metadata_json(sitecode)
    template = ImosTemplate.from_json(merged_template)
    output_nc_filename = '{institution_code}_{date_start}_{site_name}_DM_WAVE-PARAMETERS_END-{date_end}.nc'.format(
        institution_code=template.global_attributes['institution_code'].upper(),
        site_name=template.global_attributes['site_name'].upper().replace(" ", "-"),
        date_start=datetime.datetime.strftime(df.TIME.min(), '%Y%m%d'),
        date_end=datetime.datetime.strftime(df.TIME.max(), '%Y%m%d')
    )
    # Time in IMOS format
    df['TIME'] = date2num(df['TIME'], 'days since 1950-01-01 00:00:00 UTC', 'gregorian')

    set_final_attributes(template)

    netcdf_path = os.path.join(output_path, output_nc_filename)
    template.to_netcdf(netcdf_path)


def set_final_attributes(template):
    # finalise global attributes
    for df_variable_name in df.columns.values:
        template.variables[df_variable_name]['_data'] = df[df_variable_name].values


    template.add_extent_attributes(time_var='TIME', vert_var=None, lat_var='LATITUDE', lon_var='LONGITUDE')
    template.global_attributes.pop('latitude')
    template.global_attributes.pop('longitude')
    template.global_attributes.pop('geospatial_vertical_min')
    template.global_attributes.pop('geospatial_vertical_max')

    title = template.global_attributes['title'] + template.global_attributes['site_name']
    abstract = template.global_attributes['title'] + template.global_attributes['site_name'] + ' between ' + \
               template.global_attributes['time_coverage_start'] + ' and ' + template.global_attributes[
                   'time_coverage_end']

    template.global_attributes.update({'title': title})
    template.global_attributes.update({'abstract': abstract})
    template.global_attributes.pop('institution_code')
    template.variables['timeSeries']['_data'] = np.int16([1])

    update_qc_att = ['valid_min', 'valid_max', 'flag_values']
    for qc_att in update_qc_att:
        template.variables['WAVE_quality_control'][qc_att] = np.int8(
            template.variables['WAVE_quality_control'][qc_att])

    template.add_date_created_attribute()

    # update type of integer attribute
    update_att_list = ['instrument_burst_interval', 'instrument_burst_duration', 'water_depth']
    for att in update_att_list:
        upd_att = np.int32(template.global_attributes[att])
        template.global_attributes.update({att: upd_att})


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser(description='Creates FV01 NetCDF files from BOM Triaxys Delayed Mode dataset.\n '
                                                 'Prints out the path of the new locally generated FV01 file.')
    parser.add_argument('-i', "--wave-dataset-org-path",
                        dest='dataset_path',
                        type=str,
                        default='',
                        help="path to original wave dataset",
                        required=True)
    parser.add_argument('-o', '--output-path',
                        dest='output_path',
                        type=str,
                        default=None,
                        help="output directory of FV01 netcdf file. (Optional)",
                        required=False)
    vargs = parser.parse_args()

    if vargs.output_path is None:
        vargs.output_path = tempfile.mkdtemp()

    if not os.path.exists(vargs.output_path):
        try:
            os.makedirs(vargs.output_path)
        except Exception:
            raise ValueError('{path} not a valid path'.format(path=vargs.output_path))
            sys.exit(1)

    return vargs


if __name__ == '__main__':
    vargs = args()
    flist = [f for f in glob.glob('{dir}/*'.format(dir=vargs.dataset_path)) if re.match('.*_AXYS_Listing.csv$', f)]

    formats = [HEADER_2019, HEADER_2020, HEADER_2021]

    for file in flist:
        i = 0
        sitecode = os.path.basename(file)[0:4]
        for form in formats:
            if re.match(form['regex'], file):
                df = get_data(file, sitecode, formats[i])
                break
            else:
                i += 1
                df = []
                continue

        if isinstance(df, pd.DataFrame):
            generate_netcdf(df, sitecode,vargs.output_path)

    print(vargs.output_path)

