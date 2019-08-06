from __future__ import print_function
import sys
from dateutil.parser import parse
from datetime import datetime
import json
from netCDF4 import Dataset
import argparse

import numpy as np
import xarray as xr
import pandas as pd

from geoserverCatalog import get_moorings_urls


def sort_files_to_aggregate(files_to_agg):
    """
    sort the list of files to aggregate by time_deployment start attribute

    :param files_to_agg: list of file URLs
    :return: list of file URLs
    """
    file_list_dataframe = pd.DataFrame(columns=["url", "deployment_date"])
    for file in files_to_agg:
        with Dataset(file) as nc:
            try:
                file_list_dataframe = file_list_dataframe.append({'url': file,
                                                                'deployment_date': parse(nc.getncattr('time_deployment_start'))},
                                                                ignore_index=True)
            except:
                print(file)

    file_list_dataframe = file_list_dataframe.sort_values(by='deployment_date')

    return list(file_list_dataframe['url'])


def good_file(nc, VoI, site_code):
    """
    Return True the file pass all the following tests:
    VoI is present
    TIME is present
    LATITUDE is present
    LONGITUDE is present
    NOMINAL_DEPTH is present as variable or attribute
    file_version is FV01
    Return False if at least one of the tests fail
    if LATITUDE is a dimension has length 1
    if LONGITUDE is a dimension has length 1

    :param nc: xarray dataset
    :param VoI: string. Variable of Interest
    :param site_code: code of the mooring site
    :return: boolean
    """

    attributes = list(nc.attrs)
    variables = list(nc.variables)
    dimensions = list(nc.dims)
    VoIdimensions = list(nc[VoI].dims)
    allowed_dimensions = ['TIME', 'LATITUDE', 'LONGITUDE']

    criteria_site = nc.site_code == site_code
    criteria_FV = 'Level 1' in nc.file_version
    criteria_TIME = 'TIME' in variables
    criteria_LATITUDE = 'LATITUDE' in variables
    criteria_LONGITUDE = 'LONGITUDE' in variables
    criteria_NOMINALDEPTH = 'NOMINAL_DEPTH' in variables or 'instrument_nominal_depth' in attributes
    criteria_VoI = VoI in variables
    criteria_VoIdimensionTIME =  'TIME' in VoIdimensions

    criteria_LAT_VoIdimension = True
    if 'LATITUDE' in VoIdimensions:
        if len(nc.LATITUDE) > 1:
            criteria_LAT_VoIdimension = False

    criteria_LON_VoIdimension = True
    if 'LONGITUDE' in VoIdimensions:
        if len(nc.LATITUDE) > 1:
            criteria_LON_VoIdimension = False

    criteria_alloweddimensions = True
    for d in range(len(VoIdimensions)):
        if VoIdimensions[d] not in allowed_dimensions:
            criteria_alloweddimensions = False
            break

    all_criteria_passed = criteria_site and \
                          criteria_FV and \
                          criteria_TIME and \
                          criteria_LATITUDE and \
                          criteria_LONGITUDE and \
                          criteria_VoI and \
                          criteria_NOMINALDEPTH and \
                          criteria_LON_VoIdimension and \
                          criteria_LAT_VoIdimension and \
                          criteria_VoIdimensionTIME and \
                          criteria_alloweddimensions

    return all_criteria_passed

def get_nominal_depth(nc):
    """
    retunr nominal depth from NOMINAL_DEPTH variable or
    if it is not present from instrument_nominal_depth global attribute

    :param nc: xarray dataset
    :return: nominal depth of the instrument
    """

    if 'NOMINAL_DEPTH' in list(nc.variables):
        nominal_depth = nc.NOMINAL_DEPTH.squeeze().values
    else:
        nominal_depth = nc.instrument_nominal_depth

    return nominal_depth


def set_globalattr(agg_dataset, templatefile, varname, site, add_attribute):
    """
    global attributes from a reference nc file and nc file

    :param agg_dataset: aggregated xarray dataset
    :param templatefile: name of the attributes JSON file
    :param varname: name of the variable of interest to aggregate
    :param site: site code
    :param add_attribute: dictionary of additional attributes to add name:value
    :return: dictionary of global attributes
    """

    timeformat = '%Y-%m-%dT%H:%M:%SZ'
    with open(templatefile) as json_file:
        global_metadata = json.load(json_file)["_global"]

    agg_attr = {'title':                    ("Long Timeseries Aggregated product: " + varname + " at " + site + " between " + \
                                             pd.to_datetime(agg_dataset.TIME.values.min()).strftime(timeformat) + " and " + \
                                             pd.to_datetime(agg_dataset.TIME.values.max()).strftime(timeformat)),
                'site_code':                site,
                'local_time_zone':          '',
                'time_coverage_start':      pd.to_datetime(agg_dataset.TIME.values.min()).strftime(timeformat),
                'time_coverage_end':        pd.to_datetime(agg_dataset.TIME.values.max()).strftime(timeformat),
                'geospatial_vertical_min':  float(agg_dataset.DEPTH.min()),
                'geospatial_vertical_max':  float(agg_dataset.DEPTH.max()),
                'geospatial_lat_min':       agg_dataset.LATITUDE.values.min(),
                'geospatial_lat_max':       agg_dataset.LATITUDE.values.max(),
                'geospatial_lon_min':       agg_dataset.LONGITUDE.values.min(),
                'geospatial_lon_max':       agg_dataset.LONGITUDE.values.max(),
                'date_created':             datetime.utcnow().strftime(timeformat),
                'history':                  datetime.utcnow().strftime(timeformat) + ': Aggregated file created.',
                'keywords':                 ', '.join(list(agg_dataset.variables) + ['AGGREGATED'])}
    global_metadata.update(agg_attr)
    global_metadata.update(add_attribute)

    return dict(sorted(global_metadata.items()))


def set_variableattr(varlist, templatefile, add_variable_attribute):
    """
    set variables variables atributes

    :param varlist: list of variable names
    :param templatefile: name of the attributes JSON file
    :return: dictionary of attributes
    """

    with open(templatefile) as json_file:
        variable_metadata = json.load(json_file)['_variables']
    variable_attributes = {key: variable_metadata[key] for key in varlist}
    if len(add_variable_attribute)>0:
        for key in add_variable_attribute.keys():
            variable_attributes[key].update(add_variable_attribute[key])

    return variable_attributes


def generate_netcdf_output_filename(fileURL, nc, VoI, file_product_type, file_version):
    """
    generate the output filename for the VoI netCDF file

    :param fileURL: file name of the first file to aggregate
    :param nc: aggregated dataset
    :param VoI: name of the variable to aggregate
    :param file_product_type: name of the product
    :param file_version: version of the output file
    :return: name of the output file
    """

    file_timeformat = '%Y%m%d'
    nc_timeformat = '%Y%m%dT%H%M%SZ'
    t_start = pd.to_datetime(nc.TIME.min().values).strftime(nc_timeformat)
    t_end = pd.to_datetime(nc.TIME.max().values).strftime(nc_timeformat)
    split_path = fileURL.split("/")
    split_parts = split_path[-1].split("_") # get the last path item (the file nanme)

    output_name = '_'.join([split_parts[0] + "_" + split_parts[1] + "_" + split_parts[2], \
                            t_start, split_parts[4], "FV0" + str(file_version), VoI, file_product_type]) + \
                            "_END-" + t_end + "_C-" + datetime.utcnow().strftime(file_timeformat) + ".nc"
    return output_name

def create_empty_dataframe(columns):
    """
    create empty dataframe from a dict with data types

    :param: variable name and variable file. List of tuples
    :return: empty dataframe
    """

    return pd.DataFrame({k: pd.Series(dtype=t) for k, t in columns})


def write_netCDF_aggfile(agg_dataset, ncout_filename, encoding):
    """
    write netcdf file

    :param agg_dataset: aggregated xarray dataset
    :param ncout_filename: name of the netCDF file to be written
    :return: name of the netCDf file written
    """

    agg_dataset.to_netcdf(ncout_filename, encoding=encoding, format='NETCDF4_CLASSIC')

    return ncout_filename

## MAIN FUNCTION
def main_aggregator(files_to_agg, var_to_agg, site_code):
    """
    Aggregates the variable of interest, its coordinates, quality control and metadata variables, from each file in
    the list into a netCDF file and returns its file name.

    :param files_to_agg: List of URLs for files to aggregate.
    :param var_to_agg: Name of variable to aggregate.
    :param site_code: code of the mooring site.
    :return: File name of the aggregated product
    :rtype: string
    """

    ## constants
    FILLVALUE = 999999.0

    ## sort the file URL in chronological order of deployment
    files_to_agg = sort_files_to_aggregate(files_to_agg)

    var_to_agg_qc = var_to_agg + '_quality_control'
    ## create empty DF for main and auxiliary variables
    MainDF_types = [(var_to_agg, float),
                    (var_to_agg_qc, np.byte),
                    ('TIME', np.float64),
                    ('DEPTH', float),
                    ('DEPTH_quality_control', np.byte),
                    ('PRES', np.float64),
                    ('PRES_quality_control', np.byte),
                    ('PRES_REL', np.float64),
                    ('PRES_REL_quality_control', np.byte),
                    ('instrument_index', int)]

    AuxDF_types = [('source_file', str),
                   ('instrument_id', str),
                   ('LONGITUDE', float),
                   ('LATITUDE', float),
                   ('NOMINAL_DEPTH', float)]

    variableMainDF = create_empty_dataframe(MainDF_types)
    variableAuxDF = create_empty_dataframe(AuxDF_types)

    ## main loop
    fileIndex = 0
    rejected_files = []
    applied_offset =[]      ## to store the PRES_REL attribute which could vary by deployment
    for file in files_to_agg:
        print(fileIndex, end=" ")
        sys.stdout.flush()

        ## it will open the netCDF files as a xarray Dataset
        with xr.open_dataset(file, decode_times=True) as nc:
            ## do only if the file pass all the sanity tests
            if good_file(nc, var_to_agg, site_code):
                varnames = list(nc.variables.keys())
                nobs = len(nc.TIME)

                ## get the in-water times
                ## important to remove the timezone aware of the converted datetime object from a string
                time_deployment_start = pd.to_datetime(parse(nc.attrs['time_deployment_start'])).tz_localize(None)
                time_deployment_end = pd.to_datetime(parse(nc.attrs['time_deployment_end'])).tz_localize(None)

                DF = pd.DataFrame({ var_to_agg: nc[var_to_agg].squeeze(),
                                    var_to_agg_qc: nc[var_to_agg + '_quality_control'].squeeze(),
                                    'TIME': nc.TIME.squeeze(),
                                    'instrument_index': np.repeat(fileIndex, nobs)})

                ## check for DEPTH/PRES variables in the nc and its qc flags
                if 'DEPTH' in varnames:
                    DF['DEPTH'] = nc.DEPTH.squeeze()
                    if 'DEPTH_quality_control' in varnames:
                        DF['DEPTH_quality_control'] = nc.DEPTH_quality_control.squeeze()
                    else:
                        DF['DEPTH_quality_control'] = np.repeat(0, nobs)
                else:
                    DF['DEPTH'] = np.repeat(FILLVALUE, nobs)
                    DF['DEPTH_quality_control'] = np.repeat(9, nobs)

                if 'PRES' in varnames:
                    DF['PRES'] = nc.PRES.squeeze()
                    if 'PRES_quality_control' in varnames:
                        DF['PRES_quality_control'] = nc.PRES_quality_control.squeeze()
                    else:
                        DF['PRES_quality_control'] = np.repeat(0, nobs)
                else:
                    DF['PRES'] = np.repeat(FILLVALUE, nobs)
                    DF['PRES_quality_control'] = np.repeat(9, nobs)

                if 'PRES_REL' in varnames:
                    DF['PRES_REL'] = nc.PRES_REL.squeeze()
                    try:
                        applied_offset.append(nc.PRES_REL.applied_offset)
                    except:
                        applied_offset.append(np.nan)
                    if 'PRES_REL_quality_control' in varnames:
                        DF['PRES_REL_quality_control'] = nc.PRES_REL_quality_control.squeeze()
                    else:
                        DF['PRES_REL_quality_control'] = np.repeat(0, nobs)
                else:
                    DF['PRES_REL'] = np.repeat(FILLVALUE, nobs)
                    DF['PRES_REL_quality_control'] = np.repeat(9, nobs)
                    applied_offset.append(np.nan)


                ## select only in water data
                DF = DF[(DF['TIME']>=time_deployment_start) & (DF['TIME']<=time_deployment_end)]

                ## append data
                variableMainDF = pd.concat([variableMainDF, DF], ignore_index=True, sort=False)


                # append auxiliary data
                variableAuxDF = variableAuxDF.append({'source_file': file,
                                                      'instrument_id': nc.attrs['deployment_code'] + '; ' + nc.attrs['instrument'] + '; ' + nc.attrs['instrument_serial_number'],
                                                      'LONGITUDE': nc.LONGITUDE.squeeze().values,
                                                      'LATITUDE': nc.LATITUDE.squeeze().values,
                                                      'NOMINAL_DEPTH': get_nominal_depth(nc)}, ignore_index = True)
                fileIndex += 1
            else:
                rejected_files.append(file)

    print()


    ## rename indices
    variableAuxDF.index.rename('INSTRUMENT', inplace=True)
    variableMainDF.index.rename('OBSERVATION', inplace=True)

    ## get the list of variables
    varlist = list(variableMainDF.columns) + list(variableAuxDF.columns)


    ## set variable attributes
    add_variable_attribute = {'PRES_REL': {'applied_offset_by_instrument': applied_offset}}
    variable_attributes_templatefile = 'TSagg_metadata.json'
    variable_attributes = set_variableattr(varlist, variable_attributes_templatefile, add_variable_attribute)
    time_units = variable_attributes['TIME'].pop('units')
    time_calendar = variable_attributes['TIME'].pop('calendar')

    ## build the output file
    agg_dataset = xr.Dataset({var_to_agg:                   (['OBSERVATION'],variableMainDF[var_to_agg].astype('float32'), variable_attributes[var_to_agg]),
                          var_to_agg + '_quality_control':  (['OBSERVATION'],variableMainDF[var_to_agg_qc].astype(np.byte), variable_attributes[var_to_agg+'_quality_control']),
                          'TIME':                           (['OBSERVATION'],variableMainDF['TIME'], variable_attributes['TIME']),
                          'DEPTH':                          (['OBSERVATION'],variableMainDF['DEPTH'].astype('float32'), variable_attributes['DEPTH']),
                          'DEPTH_quality_control':          (['OBSERVATION'],variableMainDF['DEPTH_quality_control'].astype(np.byte), variable_attributes['DEPTH_quality_control']),
                          'PRES':                           (['OBSERVATION'],variableMainDF['PRES'].astype('float32'), variable_attributes['PRES']),
                          'PRES_quality_control':           (['OBSERVATION'],variableMainDF['PRES_quality_control'].astype(np.byte), variable_attributes['PRES_quality_control']),
                          'PRES_REL':                       (['OBSERVATION'],variableMainDF['PRES_REL'].astype('float32'), variable_attributes['PRES_REL']),
                          'PRES_REL_quality_control':       (['OBSERVATION'],variableMainDF['PRES_REL_quality_control'].astype(np.byte), variable_attributes['PRES_REL_quality_control']),
                          'instrument_index':               (['OBSERVATION'],variableMainDF['instrument_index'].astype('int64'), variable_attributes['instrument_index']),
                          'LONGITUDE':                      (['INSTRUMENT'], variableAuxDF['LONGITUDE'].astype('float32'), variable_attributes['LONGITUDE']),
                          'LATITUDE':                       (['INSTRUMENT'], variableAuxDF['LATITUDE'].astype('float32'), variable_attributes['LATITUDE']),
                          'NOMINAL_DEPTH':                  (['INSTRUMENT'], variableAuxDF['NOMINAL_DEPTH']. astype('float32'), variable_attributes['NOMINAL_DEPTH']),
                          'instrument_id':                  (['INSTRUMENT'], variableAuxDF['instrument_id'].astype('|S256'), variable_attributes['instrument_id'] ),
                          'source_file':                    (['INSTRUMENT'], variableAuxDF['source_file'].astype('|S256'), variable_attributes['source_file'])})


    ## Set global attrs
    globalattr_file = 'TSagg_metadata.json'
    add_attribute = {'rejected_files': "\n".join(rejected_files)}
    agg_dataset.attrs = set_globalattr(agg_dataset, globalattr_file, var_to_agg, site_code, add_attribute)

    ## create the output file name and write the aggregated product as netCDF
    ncout_filename = generate_netcdf_output_filename(fileURL=files_to_agg[0], nc=agg_dataset, VoI=var_to_agg, file_product_type='aggregated-time-series', file_version=1)

    encoding = {'TIME':                     {'_FillValue': False,
                                             'units': time_units,
                                             'calendar': time_calendar},
                'LONGITUDE':                {'_FillValue': False},
                'LATITUDE':                 {'_FillValue': False}}

    write_netCDF_aggfile(agg_dataset, ncout_filename, encoding)

    return ncout_filename


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Concatenate ONE variable from ALL instruments from ALL deployments from ONE site")
    parser.add_argument('-var', dest='varname', help='name of the variable to concatenate. Like TEMP, PSAL', required=True)
    parser.add_argument('-site', dest='site_code', help='site code, like NRMMAI',  required=True)
    parser.add_argument('-files', dest='filenames', help='name of the file that contains the source URLs', required=True)
    args = parser.parse_args()

    files_to_aggregate = pd.read_csv(args.filenames, header=-1)[0]

    print(main_aggregator(files_to_agg=files_to_aggregate, var_to_agg=args.varname, site_code=args.site_code))
