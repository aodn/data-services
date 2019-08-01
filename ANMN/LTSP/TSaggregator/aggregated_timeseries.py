from __future__ import print_function
import sys
from dateutil.parser import parse
from datetime import datetime
import json
from netCDF4 import Dataset

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
            file_list_dataframe = file_list_dataframe.append({'url': file,
                                                              'deployment_date': parse(nc.getncattr('time_deployment_start'))},
                                                              ignore_index=True)
    file_list_dataframe = file_list_dataframe.sort_values(by='deployment_date')

    return list(file_list_dataframe['url'])


def good_file(nc, VoI, site):
    """
    Return True the file pass all the following tests:
    VoI is present
    TIME is present
    LATITUDE is present
    LONGITUDE is present
    NOMINAL_DEPTH is present as variable or attribute
    file_version is FV01
    Return False if at least one of the tests fail

    :param nc: xarray dataset
    :param VoI: string. Variable of Interest
    :return: boolean
    """

    attributes = list(nc.attrs)
    variables = list(nc.variables)

    criteria_site = nc.site_code == site
    criteria_FV = 'Level 1' in nc.file_version
    criteria_TIME = 'TIME' in variables
    criteria_LATITUDE = 'LATITUDE' in variables
    criteria_LONGITUDE = 'LONGITUDE' in variables
    criteria_NOMINALDEPTH = 'NOMINAL_DEPTH' in variables or 'instrument_nominal_depth' in attributes
    criteria_VoI = VoI in variables
    criteria_dimensionTIME = 'TIME' in list(nc.dims)

    all_criteria_passed = criteria_site and \
                          criteria_FV and \
                          criteria_TIME and \
                          criteria_LATITUDE and \
                          criteria_LONGITUDE and \
                          criteria_VoI and \
                          criteria_NOMINALDEPTH and \
                          criteria_dimensionTIME

    return all_criteria_passed



def set_globalattr(agg_Dataset, templatefile, varname, site, add_attribute=None):
    """
    global attributes from a reference nc file and nc file

    :param agg_Dataset: aggregated xarray dataset
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
                                             pd.to_datetime(agg_Dataset.TIME.values.min()).strftime(timeformat) + " and " + \
                                             pd.to_datetime(agg_Dataset.TIME.values.max()).strftime(timeformat)),
                'site_code':                site,
                'local_time_zone':          '',
                'time_coverage_start':      pd.to_datetime(agg_Dataset.TIME.values.min()).strftime(timeformat),
                'time_coverage_end':        pd.to_datetime(agg_Dataset.TIME.values.max()).strftime(timeformat),
                'geospatial_vertical_min':  float(agg_Dataset.DEPTH.min()),
                'geospatial_vertical_max':  float(agg_Dataset.DEPTH.max()),
                'geospatial_lat_min':       agg_Dataset.LATITUDE.values.min(),
                'geospatial_lat_max':       agg_Dataset.LATITUDE.values.max(),
                'geospatial_lon_min':       agg_Dataset.LONGITUDE.values.min(),
                'geospatial_lon_max':       agg_Dataset.LONGITUDE.values.max(),
                'date_created':             datetime.utcnow().strftime(timeformat),
                'history':                  datetime.utcnow().strftime(timeformat) + ': Aggregated file created.',
                'keywords':                 ', '.join(list(agg_Dataset.variables) + ['AGGREGATED'])}
    global_metadata.update(agg_attr)
    global_metadata.update(add_attribute)

    return dict(sorted(global_metadata.items()))


def set_variableattr(varlist, templatefile):
    """
    set variables variables atributes

    :param varlist: list of variable names
    :param templatefile: name of the attributes JSON file
    :return: dictionary of attributes
    """

    with open(templatefile) as json_file:
        variable_metadata = json.load(json_file)['_variables']

    return {key: variable_metadata[key] for key in varlist}


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


def write_netCDF_aggfile(aggDataset, ncout_filename):
    """
    write netcdf file

    :param aggDataset: aggregated xarray dataset
    :param ncout_filename: name of the netCDF file to be written
    :return: name of the netCDf file written
    """

    encoding = {'TIME':                     {'_FillValue': False,
                                             'units': "days since 1950-01-01 00:00:00 UTC",
                                             'calendar': 'gregorian'},
                'LONGITUDE':                {'_FillValue': False},
                'LATITUDE':                 {'_FillValue': False}}
    aggDataset.to_netcdf(ncout_filename, encoding=encoding, format='NETCDF4_CLASSIC')

    return ncout_filename

## MAIN FUNCTION
def main_aggregator(files_to_agg, var_to_agg, site_code):
    """
    Aggregates the variable of interest, its coordinates, quality control and metadata variables, from each file in
    the list into an xarray Dataset.

    :param files_to_agg: List of URLs for files to aggregate.
    :param var_to_agg: Name of variable to aggregate.
    :return: aggregated dataset
    :rtype: xarray.Dataset
    """

    ## constants
    UNITS = 'days since 1950-01-01 00:00 UTC'
    CALENDAR = 'gregorian'
    FILLVALUE = 999999.0

    ## sort the file URL in chronological order of deployment
    files_to_agg = sort_files_to_aggregate(files_to_agg)


    ## create empty DF for main and auxiliary variables
    MainDF_types = [('VAR', float),
                    ('VARqc', np.byte),
                    ('TIME', np.float64),
                    ('DEPTH', float),
                    ('DEPTH_quality_control', np.byte),
                    ('PRES', np.float64),
                    ('PRES_REL', np.float64),
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
    for file in files_to_agg:
        print(fileIndex, end=" ")
        sys.stdout.flush()

        ## it will open the netCDF files as a xarray Dataset
        with xr.open_dataset(file) as nc:
            ## do only if the file has nominal_depth
            if good_file(nc, var_to_agg, site):
                varnames = list(nc.variables.keys())
                nobs = len(nc.TIME)

                ## get the in-water times
                ## important to remove the timezone aware of the converted datetime object from a string
                time_deployment_start = pd.to_datetime(parse(nc.attrs['time_deployment_start'])).tz_localize(None)
                time_deployment_end = pd.to_datetime(parse(nc.attrs['time_deployment_end'])).tz_localize(None)

                ## Check if DEPTH is present. If not store FillValues
                DF = pd.DataFrame({ 'VAR': nc[var_to_agg].squeeze(),
                                    'VARqc': nc[var_to_agg + '_quality_control'].squeeze(),
                                    'TIME': nc.TIME.squeeze(),
                                    'instrument_index': np.repeat(fileIndex, nobs)})

                ## check for DEPTH/PRES variables in the nc and its qc flags
                if 'DEPTH' in varnames:
                    DF['DEPTH'] = nc.DEPTH.squeeze()
                    if 'DEPTH_quality_control' in varnames:
                        DF['DEPTH_quality_control'] = nc.DEPTH_quality_control.squeeze()
                    else:
                        DF['DEPTH_quality_control'] = np.repeat(9, nobs)
                else:
                    DF['DEPTH'] = np.repeat(FILLVALUE, nobs)
                    DF['DEPTH_quality_control'] = np.repeat(9, nobs)

                if 'PRES' in varnames:
                    DF['PRES'] = nc.PRES.squeeze()
                    if 'PRES_quality_control' in varnames:
                        DF['PRES_quality_control'] = nc.PRES_quality_control.squeeze()
                    else:
                        DF['PRES_quality_control'] = np.repeat(9, nobs)
                else:
                    DF['PRES'] = np.repeat(FILLVALUE, nobs)
                    DF['PRES_quality_control'] = np.repeat(9, nobs)

                if 'PRES_REL' in varnames:
                    DF['PRES_REL'] = nc.PRES_REL.squeeze()
                    if 'PRES_REL_quality_control' in varnames:
                        DF['PRES_REL_quality_control'] = nc.PRES_REL_quality_control.squeeze()
                    else:
                        DF['PRES_REL_quality_control'] = np.repeat(9, nobs)
                else:
                    DF['PRES_REL'] = np.repeat(FILLVALUE, nobs)
                    DF['PRES_REL_quality_control'] = np.repeat(9, nobs)


                ## select only in water data
                DF = DF[(DF['TIME']>=time_deployment_start) & (DF['TIME']<=time_deployment_end)]

                ## append data
                variableMainDF = pd.concat([variableMainDF, DF], ignore_index=True, sort=False)

                # append auxiliary data
                variableAuxDF = variableAuxDF.append({'source_file': file,
                                                      'instrument_id': nc.attrs['deployment_code'] + '; ' + nc.attrs['instrument'] + '; ' + nc.attrs['instrument_serial_number'],
                                                      'LONGITUDE': nc.LONGITUDE.squeeze().values,
                                                      'LATITUDE': nc.LATITUDE.squeeze().values,
                                                      'NOMINAL_DEPTH': nc.NOMINAL_DEPTH.squeeze().values}, ignore_index = True)
                fileIndex += 1
            else:
                rejected_files += [file]

    print()

    ## sort by TIME
    variableMainDF.sort_values(by=['TIME'], inplace=True)

    ## rename indices
    variableAuxDF.index.rename('INSTRUMENT', inplace=True)
    variableMainDF.index.rename('OBSERVATION', inplace=True)

    ## get the list of variables
    varlist = list(variableMainDF.columns) + list(variableAuxDF.columns)
    varlist[0] = var_to_agg
    varlist[1] = var_to_agg + "_quality_control"

    ## set variable attributes
    variable_attributes_templatefile = 'TSagg_metadata.json'
    #variable_attributes = set_variableattr(nc, var_to_agg, variable_attributes_templatefile)
    variable_attributes = set_variableattr(varlist, variable_attributes_templatefile)

    ## build the output file
    nc_aggr = xr.Dataset({var_to_agg:                       (['OBSERVATION'],variableMainDF['VAR'].astype('float32'), variable_attributes[var_to_agg]),
                          var_to_agg + '_quality_control':  (['OBSERVATION'],variableMainDF['VARqc'].astype(np.byte), variable_attributes[var_to_agg+'_quality_control']),
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
    add_attribute = {'rejected_files': ", ".join(rejected_files)}
    nc_aggr.attrs = set_globalattr(nc_aggr, globalattr_file, var_to_agg, site, add_attribute)

    ## create the output file name and write the aggregated product as netCDF
    ncout_filename = generate_netcdf_output_filename(fileURL=files_to_aggregate[0], nc=nc_aggr, VoI=varname, file_product_type='aggregated-time-series', file_version=1)
    write_netCDF_aggfile(nc_aggr, ncout_filename)

    return ncout_filename


if __name__ == "__main__":

    ## This is the confuration file
    with open('TSaggr_config.json') as json_file:
        TSaggr_arguments = json.load(json_file)
    varname = TSaggr_arguments['varname']
    site = TSaggr_arguments['site']

    ## Get the URLS according to the arguments from the config file
    # files_to_aggregate = get_moorings_urls(**TSaggr_arguments)
    # print('number of files: %i' % len(files_to_aggregate))

    # to test
    # files_to_aggregate = ['http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141215T160000Z_NRSROT_FV01_NRSROT-1412-SBE39-33_END-20150331T063000Z_C-20180508T001839Z.nc',
    # 'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-TDR-2050-57_END-20150331T065000Z_C-20180508T001840Z.nc',
    # 'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-43_END-20150331T063000Z_C-20180508T001839Z.nc',
    # 'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-27_END-20150331T061500Z_C-20180508T001839Z.nc']

    # ## to test with a (large) WQM file
    site = 'NRSROT'
    files_to_aggregate = ['http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141215T160000Z_NRSROT_FV01_NRSROT-1412-SBE39-33_END-20150331T063000Z_C-20180508T001839Z.nc',
    'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-43_END-20150331T063000Z_C-20180508T001839Z.nc',
    'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Biogeochem_timeseries/IMOS_ANMN-NRS_BCKOSTUZ_20151208T080040Z_NRSROT_FV01_NRSROT-1512-WQM-24_END-20160411T021734Z_C-20180504T071457Z.nc',
    'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-27_END-20150331T061500Z_C-20180508T001839Z.nc',
    'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-TDR-2050-57_END-20150331T065000Z_C-20180508T001840Z.nc',
    'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSKAI/Temperature/IMOS_ANMN-NRS_TZ_20110217T000000Z_NRSKAI_FV01_NRSKAI-1103-Aqualogger-520PT-41_END-20110725T060000Z_C-20160418T021746Z.nc',
    'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/non-QC/IMOS_ANMN-NRS_TZ_20081120T070000Z_NRSROT_FV00_NRSROT-0811-SBE39-27_END-20090219T020000Z_C-20180810T044335Z.nc',
    'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_Z_20181213T080000Z_NRSROT_FV01_NRSROT-1812-DR-1050-57_END-20190524T024500Z_C-20190618T053025Z.nc']



    print(main_aggregator(files_to_agg=files_to_aggregate, var_to_agg=varname, site_code=site))
