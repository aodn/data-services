from __future__ import print_function
import sys
from dateutil.parser import parse
from datetime import datetime
import json

import numpy as np
import xarray as xr
import pandas as pd

from geoserverCatalog import get_moorings_urls


def set_globalattr(nc, templatefile, varname, site):
    """
    global attributes from a reference nc file and nc file
    """
    timeformat = '%Y-%m-%dT%H:%M:%SZ'
    with open(templatefile) as json_file:
        global_metadata = json.load(json_file)

    agg_attr = {'title':                    ("Long Timeseries Aggregated product: " + varname + " at " + site + " between " + \
                                             pd.to_datetime(nc.TIME.values.min()).strftime(timeformat) + " and " + \
                                             pd.to_datetime(nc.TIME.values.max()).strftime(timeformat)),
                'site_code':                site,
                'local_time_zone':          '',
                'time_coverage_start':      pd.to_datetime(nc.TIME.values.min()).strftime(timeformat),
                'time_coverage_end':        pd.to_datetime(nc.TIME.values.max()).strftime(timeformat),
                'geospatial_vertical_min':  float(nc.DEPTH.min()),
                'geospatial_vertical_max':  float(nc.DEPTH.max()),
                'geospatial_lat_min':       nc.LATITUDE.values.min(),
                'geospatial_lat_max':       nc.LATITUDE.values.max(),
                'geospatial_lon_min':       nc.LONGITUDE.values.min(),
                'geospatial_lon_max':       nc.LONGITUDE.values.max(),
                'date_created':             datetime.utcnow().strftime(timeformat),
                'history':                  datetime.utcnow().strftime(timeformat) + ': Aggregated file created.',
                'keywords':                 ', '.join(list(nc.variables) + ['AGGREGATED'])}
    global_metadata.update(agg_attr)

    return dict(sorted(global_metadata.items()))

def set_variableattr(nc, varname, templatefile):
    """
    Set variable attributes from a template file and
    from information collected from the resulting file
    """
    with open(templatefile) as json_file:
        variable_metadata = json.load(json_file)

    variable_metadata['VoI'] = nc[varname].attrs
    if '_ChunkSizes' in variable_metadata['VoI']:
        del variable_metadata['VoI']['_ChunkSizes']
    variable_metadata['VoI_quality_control'] = nc[varname+'_quality_control'].attrs
    if '_ChunkSizes' in variable_metadata['VoI_quality_control']:
        del variable_metadata['VoI_quality_control']['_ChunkSizes']

    variable_metadata[varname] = variable_metadata.pop('VoI')
    variable_metadata[varname+'_quality_control'] = variable_metadata.pop('VoI_quality_control')
    return dict(sorted(variable_metadata.items()))

def generate_netcdf_output_filename(fileURL, nc, VoI, file_product_type, file_version):
    """
    generate the output filename for the VoI
    nc is a xarray Dataset
    """
    file_timeformat = '%Y%m%d'
    nc_timeformat = '%Y%m%dT%H%M%SZ'

    # t_start = nc.indexes['TIME'].to_datetimeindex().min().strftime(nc_timeformat)
    # t_end = nc.indexes['TIME'].to_datetimeindex().max().strftime(nc_timeformat)
    t_start = pd.to_datetime(nc.TIME.min().values).strftime(nc_timeformat)
    t_end = pd.to_datetime(nc.TIME.min().values).strftime(nc_timeformat)

    split_path = fileURL.split("/")
    split_parts = split_path[-1].split("_") # get the last path item (the file nanme)

    output_name = split_parts[0] + "_" + split_parts[1] + "_" + split_parts[2] \
                 + "_" + t_start \
                 + "_" + split_parts[4] \
                 + "_" + "FV0" + str(file_version) \
                 + "_" + VoI + "_" + file_product_type + "-aggregate" \
                 + "_END-" + t_end \
                 + "_C-" + datetime.utcnow().strftime(file_timeformat) \
                 + ".nc"
    return output_name

def create_empty_dataframe(columns):
    # create the dataframe from a dict with data types
    return pd.DataFrame({k: pd.Series(dtype=t) for k, t in columns})


def main_aggregator(files_to_agg, var_to_agg):
"""
Take a list of URLs extract the VoI and aggregates it into two dpandas dataframes
the first contain the variable with Observation_index as dimension
the second will contain the metadata variables with instrument_index as dimension
both data frames are combinen into a xarray Dataset and returned
"""
    ## constants
    UNITS = 'days since 1950-01-01 00:00 UTC'
    CALENDAR = 'gregorian'
    FILLVALUE = 999999.0
    FILLVALUEqc = 99

    ## create empty DF for main and auxiliary variables
    MainDF_types = [#('ObservationID', int),
                    ('TIME', np.float64),
                    ('VAR', float),
                    ('VARqc', np.byte),
                    ('DEPTH', float),
                    ('DEPTH_quality_control', np.byte),
                    ('INSTRUMENT_ID', int)]

    AuxDF_types = [('FILENAME', str),
                   ('PLATFORM_CODE', str),
                   ('INSTRUMENT_TYPE', str),
                   ('LONGITUDE', float),
                   ('LATITUDE', float),
                   ('NOMINAL_DEPTH', float)]

    variableMainDF = create_empty_dataframe(MainDF_types)
    variableAuxDF = create_empty_dataframe(AuxDF_types)

    ## main loop
    fileIndex = 0
    for file in files_to_agg:
        print(fileIndex, end=" ")
        sys.stdout.flush()

        ## it will open the netCDF files as a xarray Dataset
        with xr.open_dataset(file) as nc:
            varnames = list(nc.variables.keys())

            ## get the in-water times
            ## important to remove the timezone aware of the converted datetime object from a string
            deploymentStart = pd.to_datetime(parse(nc.attrs['time_deployment_start'])).tz_localize(None)
            deploymentEnd = pd.to_datetime(parse(nc.attrs['time_deployment_end'])).tz_localize(None)

            ## Check if DEPTH is present. If not store FillValues
            if 'DEPTH' in varnames:
                DF = pd.DataFrame({ 'TIME': nc.TIME.squeeze(),
                                    'VAR': nc[var_to_agg].squeeze(),
                                    'VARqc': nc[var_to_agg + '_quality_control'].squeeze(),
                                    'DEPTH': nc.DEPTH.squeeze(),
                                    'DEPTH_quality_control': nc.DEPTH_quality_control.squeeze(),
                                    'INSTRUMENT_ID': np.repeat(fileIndex, len(nc['TIME']))})
            else:
                DF = pd.DataFrame({ 'TIME': nc.TIME.squeeze(),
                                    'VAR': nc[var_to_agg].squeeze(),
                                    'VARqc': nc[var_to_agg + '_quality_control'].squeeze(),
                                    'INSTRUMENT_ID': np.repeat(fileIndex, len(nc['TIME'])),
                                    'DEPTH': np.repeat(FILLVALUE, len(nc['TIME'])),
                                    'DEPTH_quality_control': np.repeat(FILLVALUEqc, len(nc['TIME']))})

            ## select only in water data
            DF = DF[(DF['TIME']>=deploymentStart) & (DF['TIME']<=deploymentEnd)]

            ## append data
            variableMainDF = pd.concat([variableMainDF, DF], ignore_index=True)

            # append auxiliary data
            variableAuxDF = variableAuxDF.append({'FILENAME': file,
                                                  'PLATFORM_CODE': nc.attrs['platform_code'],
                                                  'INSTRUMENT_TYPE': nc.attrs['deployment_code'] + '-' + nc.attrs['instrument'] + '-' + nc.attrs['instrument_serial_number'],
                                                  'LONGITUDE': nc.LONGITUDE.squeeze().values,
                                                  'LATITUDE': nc.LATITUDE.squeeze().values,
                                                  'NOMINAL_DEPTH': nc.attrs['instrument_nominal_depth']}, ignore_index = True)
            fileIndex += 1
    print()

    ## rename indices
    variableAuxDF.index.rename('InstrumentIndex', inplace=True)
    variableMainDF.index.rename('ObservationIndex', inplace=True)

    ## get variable attributes
    variable_attributes_templatefile = 'TSagg_variableAttributes.json'
    variable_attributes = set_variableattr(nc, var_to_agg, variable_attributes_templatefile)

    ## build the output file
    nc_aggr = xr.Dataset({var_to_agg:                       (['ObservationIndex'],variableMainDF['VAR'].astype('float32'), variable_attributes[var_to_agg]),
                          var_to_agg + '_quality_control':  (['ObservationIndex'],variableMainDF['VARqc'].astype(np.byte), variable_attributes[var_to_agg+'_quality_control']),
                          'TIME':                           (['ObservationIndex'],variableMainDF['TIME'], variable_attributes['TIME']),
                          'DEPTH':                          (['ObservationIndex'],variableMainDF['DEPTH'].astype('float32'), variable_attributes['DEPTH']),
                          'DEPTH_quality_control':          (['ObservationIndex'],variableMainDF['DEPTH_quality_control'].astype(np.byte), variable_attributes['DEPTH_quality_control']),
                          'instrument_index':               (['ObservationIndex'],variableMainDF['INSTRUMENT_ID'].astype('int64'), variable_attributes['INSTRUMENT_ID']),
                          'LONGITUDE':                      (['InstrumentIndex'], variableAuxDF['LONGITUDE'].astype('float32'), variable_attributes['LONGITUDE']),
                          'LATITUDE':                       (['InstrumentIndex'], variableAuxDF['LATITUDE'].astype('float32'), variable_attributes['LATITUDE']),
                          'NOMINAL_DEPTH':                  (['InstrumentIndex'], variableAuxDF['NOMINAL_DEPTH']. astype('float32'), variable_attributes['NOMINAL_DEPTH']),
                          'instrument_id':                  (['InstrumentIndex'], variableAuxDF['INSTRUMENT_TYPE'].astype('str'), variable_attributes['INSTRUMENT_TYPE'] ),
                          'source_file':                    (['InstrumentIndex'], variableAuxDF['FILENAME'].astype('str'), variable_attributes['FILENAME'])})

    ## modify the encoding of the TIME variable to comply with the CF reference time units
    nc_aggr.TIME.encoding['units'] = UNITS
    nc_aggr.TIME.encoding['calendar'] = CALENDAR
    nc_aggr.DEPTH.encoding['_FillValue'] = FILLVALUE
    nc_aggr.DEPTH_quality_control['_FillValue'] = FILLVALUEqc


    return nc_aggr



if __name__ == "__main__":

    ## This is the confuration file
    with open('TSaggr_config.json') as json_file:
        TSaggr_arguments = json.load(json_file)
    varname = TSaggr_arguments['varname']
    site = TSaggr_arguments['site']

    ## Get the URLS according to the arguments from the config file
    files_to_aggregate = get_moorings_urls(**TSaggr_arguments)
    print('number of files: %i' % len(files_to_aggregate))

    # # to test
    # files_to_aggregate = ['http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141215T160000Z_NRSROT_FV01_NRSROT-1412-SBE39-33_END-20150331T063000Z_C-20180508T001839Z.nc',
    # 'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20140919T050000Z_NRSROT-ADCP_FV01_NRSROT-ADCP-1409-TR-1060-43_END-20150128T030000Z_C-20150129T091556Z.nc',
    # 'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-43_END-20150331T063000Z_C-20180508T001839Z.nc',
    # 'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-27_END-20150331T061500Z_C-20180508T001839Z.nc',
    # 'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-TDR-2050-57_END-20150331T065000Z_C-20180508T001840Z.nc']

    ## to test with one file only
    #files_to_aggregate = ['http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/QLD/GBRMYR/Biogeochem_timeseries/IMOS_ANMN-QLD_CKOSTUZ_20161121T005927Z_GBRMYR_FV01_GBRMYR-1611-WQM-195_END-20170606T080027Z_C-20170626T052818Z.nc']

    nc = main_aggregator(files_to_agg=files_to_aggregate, var_to_agg=varname)

    ## set global attributes
    globalattr_file = 'TSagg_globalmetadata.json'
    nc.attrs = set_globalattr(nc, globalattr_file, varname, site)


    ncout_filename = generate_netcdf_output_filename(fileURL=files_to_aggregate[0], nc=nc, VoI=varname, file_product_type='Full', file_version=1)
    print(ncout_filename)

    ## set encoding for netCDF file
    encoding = {'TIME':                     {'_FillValue': False,
                                             'units': 'days since 1950-01-01 00:00 UTC',
                                             'calendar': 'gregorian'},
                'LATITUDE':                 {'_FillValue': False},
                'LONGITUDE':                {'_FillValue': False},
                'DEPTH':                    {'_FillValue': 999999.0},
                'DEPTH_quality_control':    {'_FillValue': 99},
                varname:                    {'_FillValue': 999999.0},
                varname+'_quality_control': {'_FillValue': 99}}

    nc.to_netcdf(ncout_filename, encoding=encoding)
