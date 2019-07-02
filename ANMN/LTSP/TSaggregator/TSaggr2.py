from __future__ import print_function
import sys
from dateutil.parser import parse
from datetime import datetime
import json

import numpy as np
import xarray as xr
import pandas as pd

from geoserverCatalog import get_moorings_urls


def set_globalattr(agg_attr, templatefile):
    """
    global attributes from a reference nc file, dict of aggregator specific attrs,
    and dict of global attr template.
    """
    with open(templatefile) as json_file:
        global_metadata = json.load(json_file)
    global_metadata.update(agg_attr)

    return dict(sorted(global_metadata.items()))


def set_variableattr(nc, varname, templatefile):
    """
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
    nc is a xarray
    """
    file_timeformat = '%Y%m%d'
    nc_timeformat = '%Y%m%dT%H%M%SZ'
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


## create empty DF with multiple dtypes
def create_empty_dataframe(columns):
    #index = pd.Index([], name=columns[0][0], dtype=columns[0][1])
    # create the dataframe from a dict
    return pd.DataFrame({k: pd.Series(dtype=t) for k, t in columns})


def main_aggregator(files_to_agg, var_to_agg):

    ## constants
    UNITS = 'days since 1950-01-01 00:00 UTC'
    CALENDAR = 'gregorian'

    ## create empty DF for main and auxiliary variables
    MainDF_types = [#('ObservationID', int),
                    ('TIME', float),
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


        with xr.open_dataset(file) as nc:
            varnames = list(nc.variables.keys())
            numrecords = len(nc.variables[var_to_agg])

            deploymentStart = parse(nc.attrs['time_deployment_start'])
            deploymentEnd = parse(nc.attrs['time_deployment_end'])

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
                                    'INSTRUMENT_ID': np.repeat(fileIndex, len(nc['TIME']))})

            ## select only in water data
            DF = DF[(DF['TIME']>=deploymentStart) & (DF['TIME']<=deploymentEnd)]

            ## append data
            variableMainDF = pd.concat([variableMainDF, DF], ignore_index=True)

            # append auxiliary data
            # this could be more efficient if I store the variables in a list and make one concat at the end
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

    nc_aggr.TIME.encoding['units'] = UNITS
    nc_aggr.TIME.encoding['calendar'] = CALENDAR

    ## set global attributes
    globalattr_file = 'TSagg_globalmetadata.json'
    gattr_tmp = {}  ## in case we want to add specific global attrs
    nc_aggr.attrs = set_globalattr(gattr_tmp, globalattr_file)

    return nc_aggr



if __name__ == "__main__":

    with open('TSaggr_config.json') as json_file:
        TSaggr_arguments = json.load(json_file)
    varname = TSaggr_arguments['varname']

    files_to_aggregate = get_moorings_urls(**TSaggr_arguments)
    # files_to_aggregate = get_moorings_urls(varname=varname, site=site, featuretype=featuretype, fileversion=fileversion, realtime=realtime, datacategory=datacategory, timestart=datestart, timeend=dateend, filterout=filterout)
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

    ncout_filename = generate_netcdf_output_filename(fileURL=files_to_aggregate[0], nc=nc, VoI=varname, file_product_type='Full', file_version=1)
    print(ncout_filename)

    ## set encoding for netCDF file
    encoding = {'TIME':                     {'_FillValue': False},
                'LATITUDE':                 {'_FillValue': False},
                'LONGITUDE':                {'_FillValue': False},
                'DEPTH':                    {'_FillValue': 999999.0},
                'DEPTH_quality_control':    {'_FillValue': 99},
                varname:                    {'_FillValue': 999999.0},
                varname+'_quality_control': {'_FillValue': 99}}

    nc.to_netcdf(ncout_filename, encoding=encoding)
