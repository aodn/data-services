#!/usr/bin/env python
# -*- coding: utf-8 -*-
""" Script to convert Pigment, Absorption or TSS file into Netcdf. CSV and
plots are also generated"""


import argparse
import os
import sys
import tempfile
import warnings
from datetime import datetime
import traceback
import numpy as np
import numpy.ma as ma
import pandas as pd
import pyexcel
from generate_netcdf_att import generate_netcdf_att, get_imos_parameter_info
from matplotlib.font_manager import FontProperties
from matplotlib.pyplot import (figure, gca, legend, plot, savefig, scatter,
                               title, xlabel, ylabel, ylim)
from matplotlib import pyplot as plt
from netCDF4 import Dataset, date2num, stringtochar
from ship_callsign import ship_callsign_list

fontP = FontProperties()
fontP.set_size('small')
warnings.filterwarnings("ignore", category=FutureWarning)


class BodbawException(Exception):
    pass


def _error(message):
    " Raise an exception with the given message."
    raise BodbawException('In File \"%s\":\n%s' % (INPUT_EXCEL_PATH, message))


class ReadXlsPigmentTSS:
    """ Read XLS pigment or tss suspended matter file
    retrieve data, global attributes and variable definitions
    """

    def __init__(self, filename):
        self.sheet = pyexcel.get_sheet(file_name=filename)
        self.filename = filename
        self.get_index_start_var_def()
        self.get_index_end_gatts()
        self.get_index_start_data()
        self.get_index_end_var_def()
        self.get_index_end_data()
        self.max_data_column()

    def get_index_start_var_def(self):
        for i in range(self.sheet.number_of_rows()):
            if self.sheet[i, 0] == "TABLE COLUMNS":
                break
        self.idx_start_var_def = i + 1

    def get_index_end_gatts(self):
        self.idx_end_gatts = self.idx_start_var_def - 1

    def get_index_start_data(self):
        for i in range(self.sheet.number_of_rows()):
            if self.sheet[i, 0] == "DATA":
                break
        self.idx_start_data = i + 1

    def get_index_end_data(self):
        for i in range(self.idx_start_data, self.sheet.number_of_rows()):
            if self.sheet[i, 0] == "":
                break
        self.idx_end_data = i

    def get_index_end_var_def(self):
        self.idx_end_var_def = self.idx_start_data - 1

    def dic_gatts(self):
        """ return a dictionary of global attributes"""
        gatts = {}
        for i in range(1, self.idx_end_gatts):
            gatts[self.sheet[i, 0]] = self.sheet[i, 1]
        return gatts

    def dic_var_def(self):
        var_def = {}
        for i in range(self.idx_start_var_def + 1, self.idx_end_var_def):
            if self.sheet[i, 0] == '':
                break
            var_att = {}
            var_att[self.sheet[self.idx_start_var_def, 1]] = self.sheet[i, 1]
            var_att[self.sheet[self.idx_start_var_def, 2]] = self.sheet[i, 2]
            var_att[self.sheet[self.idx_start_var_def, 3]] = self.sheet[i, 3]
            var_att[self.sheet[self.idx_start_var_def, 4]] = self.sheet[i, 4]
            var_att[self.sheet[self.idx_start_var_def, 5]] = self.sheet[i, 5]
            var_def[self.sheet[i, 0].strip()] = var_att

        return var_def

    def data_frame(self):
        """ return the data as a pandas data frame """
        dates = []
        if self.idx_start_data + 1 == self.idx_end_data:
            dates.append(self.sheet[self.idx_end_data, 0])
        else:
            for i in range(self.idx_start_data + 1, self.idx_end_data):
                dates.append(self.sheet[i, 0])

        if dates == []:
            _error('No valid time values: {file}'.format(file=os.path.basename(self.filename)))

        data = {}
        for j in range(1, self.max_data_col):
            var_val = []
            if self.idx_start_data + 1 == self.idx_end_data:
                var_val.append(self.sheet[self.idx_end_data, j])
            else:
                for i in range(self.idx_start_data + 1, self.idx_end_data):
                    var_val.append(self.sheet[i, j])
            data[self.sheet[self.idx_start_data, j]] = var_val

        data_frame = pd.DataFrame(data, index=pd.to_datetime(dates))
        var_def = self.dic_var_def()

        if not all([col in var_def.keys() for col in data_frame.columns]):
            if '' in data_frame.columns:
                _error('Empty column in middle of data: {file}'.format(file=os.path.basename(self.filename)))
            else:
                _error('Not all variables are defined in TABLE_COLUMNS section: {file}'.format(file=os.path.basename(self.filename)))
        else:
            if data_frame.empty:
                _error('Input file could not be put into a dataframe. Debug: {file}'.format(file=os.path.basename(self.filename)))
            return data_frame

    def max_data_column(self):
        """ explicitly find the number of data columns, in case it's lower than
        the total amount of columns
        """
        non_save = self.sheet.row_at(self.idx_start_data)
        if non_save[-1] == '':
            self.max_data_col = sum([w != '' for w in non_save])
        elif non_save[-1] == ' ':
            self.max_data_col = sum([w != ' ' for w in non_save])
        else:
            self.max_data_col = self.sheet.number_of_columns()


class ReadXlsAbsorptionAC9HS6:
    """ Read XLS Absorption and AC9_HS6 file
    retrieve data, global attributes and variable definitions
    """

    def __init__(self, filename, sheetname=''):
        self.filename = filename
        self.sheetname = sheetname
        if self.has_sheet():
            self.sheet = pyexcel.get_sheet(file_name=filename, sheet_name=sheetname)
            self.get_index_start_var_cols_def()
            self.get_index_start_var_rows_def()
            self.get_index_end_gatts()
            self.get_index_start_data()
            self.get_index_end_var_rows_def()
            self.get_index_end_var_cols_def()
            self.idx_end_data = self.sheet.number_of_rows()
            self.max_data_column()
            self.get_index_start_var_row_val()

    def has_sheet(self):
        if self.sheetname == '':
            return True

        try:
            pyexcel.get_sheet(file_name=self.filename, sheet_name=self.sheetname)
            return True
        except:
            return False

    def get_index_start_var_rows_def(self):
        for i in range(self.sheet.number_of_rows()):
            if self.sheet[i, 0] == "TABLE ROWS":
                break
        self.idx_start_var_rows_def = i + 1

    def get_index_start_var_cols_def(self):
        for i in range(self.sheet.number_of_rows()):
            if self.sheet[i, 0] == "TABLE COLUMNS":
                break
        self.idx_start_var_cols_def = i + 1

    def get_index_end_gatts(self):
        self.idx_end_gatts = self.idx_start_var_rows_def - 1

    def get_index_start_data(self):
        for i in range(self.sheet.number_of_rows()):
            if self.sheet[i, 0] == "DATA":
                break
        self.idx_start_data = i + 1

    def get_index_end_var_cols_def(self):
        self.idx_end_var_cols_def = self.idx_start_data - 1

    def get_index_end_var_rows_def(self):
        self.idx_end_var_rows_def = self.idx_start_var_cols_def - 1

    def get_index_start_var_row_val(self):
        for i in range(self.idx_start_data + 1, self.sheet.number_of_rows()):
            if self.sheet[i, 0] == "":
                break
        self.idx_start_var_row_val = i

    def dic_gatts(self):
        """ return a dictionary of global attributes"""
        gatts = {}
        for i in range(1, self.idx_end_gatts):
            gatts[self.sheet[i, 0]] = self.sheet[i, 1]
        return gatts

    def dic_var_cols_def(self):
        var_def = {}
        for i in range(self.idx_start_var_cols_def + 1, self.idx_end_var_cols_def):
            var_att = {}
            var_att[self.sheet[self.idx_start_var_cols_def, 1]] = self.sheet[i, 1].strip()
            var_att[self.sheet[self.idx_start_var_cols_def, 2]] = self.sheet[i, 2].strip()
            var_att[self.sheet[self.idx_start_var_cols_def, 3]] = self.sheet[i, 3].strip()
            var_att[self.sheet[self.idx_start_var_cols_def, 4]] = self.sheet[i, 4]
            var_att[self.sheet[self.idx_start_var_cols_def, 5]] = self.sheet[i, 5].strip()
            var_def[self.sheet[i, 0].strip()] = var_att
        return var_def

    def dic_var_rows_def(self):
        var_def = {}
        for i in range(self.idx_start_var_rows_def + 1, self.idx_end_var_rows_def):
            var_att = {}
            var_att[self.sheet[self.idx_start_var_rows_def, 1]] = self.sheet[i, 1].strip()
            var_att[self.sheet[self.idx_start_var_rows_def, 2]] = self.sheet[i, 2].strip()
            var_att[self.sheet[self.idx_start_var_rows_def, 3]] = self.sheet[i, 3].strip()
            var_att[self.sheet[self.idx_start_var_rows_def, 4]] = self.sheet[i, 4]
            var_att[self.sheet[self.idx_start_var_rows_def, 5]] = self.sheet[i, 5].strip()
            var_def[self.sheet[i, 0].strip()] = var_att
        return var_def

    def data_frame_ac9_hs6(self):
        """ return data as a pandas data frame """
        data = []
        for i in range(self.idx_start_data + 2, self.idx_end_data):
            data.append(self.sheet.row_at(i)[6:self.max_data_col + 2])
        data_frame = pd.DataFrame(data)

        data_dict = dict()
        data_dict['Wavelength']    = self.sheet.row_at(self.idx_start_data + 1)[6:self.max_data_col + 2]
        data_dict['Dates']         = pd.to_datetime(self.sheet.column_at(1)[self.idx_start_data + 6:])
        data_dict['Time']          = self.sheet.column_at(1)[self.idx_start_data + 2:]
        data_dict['Station_Code']  = self.sheet.column_at(2)[self.idx_start_data + 2:]
        data_dict['Latitude']      = self.sheet.column_at(3)[self.idx_start_data + 2:]
        data_dict['Longitude']     = self.sheet.column_at(4)[self.idx_start_data + 2:]
        data_dict['Depth']         = self.sheet.column_at(5)[self.idx_start_data + 2:]
        data_dict['main_var_name'] = self.sheet.row_at(self.idx_start_data)[6:self.max_data_col + 2]

        if data_frame.empty:
            _error('Input file could not be put into a dataframe. Debug')

        return data_frame, data_dict

    def data_frame_absorption(self):
        """ return data as a pandas data frame """
        col0_data = self.sheet.column_at(0)[self.idx_start_data:]  # column zero starting at DATA part
        idx_col_val = range(2, self.max_data_col + 2)  # + 2 relates to 2 empty cols before start of data. range of data col idx

        # look for how many row of data. don't trust value output from
        # idx_end_data from python-excel package
        list_of_wavelength = self.sheet.column_at(1)[self.idx_start_var_row_val:]
        self.idx_end_data = self.idx_start_var_row_val + len([s for s in list_of_wavelength if s])

        data = []
        for i in range(self.idx_start_var_row_val, self.idx_end_data):
            data.append([self.sheet.row_at(i)[j] for j in idx_col_val])
            #val = self.sheet.row_at(i)
            #data.append([val[j] if not (type(val[j]) == str) else np.NaN for j in idx_col_val])

        data_frame = pd.DataFrame(data)
        self.idx_start_var_row_val

        data_dict = dict()
        data_dict['main_var_name'] = np.unique([self.sheet.row_at(self.idx_start_data)[i] for i in idx_col_val])

        if len(data_dict['main_var_name']) > 1:
            _error('More than one variable defined on row %s' % self.idx_start_data)

        dates                 = self.sheet.row_at(self.idx_start_data + 1)[2:self.max_data_col + 2]
        data_dict['Dates']      = pd.to_datetime(dates)
        data_dict['Wavelength'] = self.sheet.column_at(1)[self.idx_start_var_row_val:self.idx_end_data]

        data_dict['Station_Code'] = [self.sheet.row_at(self.idx_start_data + col0_data.index('Station_Code'))[i] for i in idx_col_val]
        data_dict['Latitude']     = [self.sheet.row_at(self.idx_start_data + col0_data.index('Latitude'))[i] for i in idx_col_val]
        data_dict['Longitude']    = [self.sheet.row_at(self.idx_start_data + col0_data.index('Longitude'))[i] for i in idx_col_val]
        data_dict['Depth']        = [self.sheet.row_at(self.idx_start_data + col0_data.index('Depth'))[i] for i in idx_col_val]
        if 'Sample_Number' in self.sheet.column_at(0)[self.idx_start_data:]:
            data_dict['Sample_Number'] = [self.sheet.row_at(self.idx_start_data + col0_data.index('Sample_Number'))[i] for i in idx_col_val]

        if data_frame.empty:
            _error('Input file could not be put into a dataframe. Debug')

        return data_frame, data_dict

    def max_data_column(self):
        """ explicitly find the number of data columns, in case it's lower than
        the total amount of columns
        """
        non_save = self.sheet.row_at(self.idx_start_data)[2:]
        if non_save[-1] == '' or non_save[-1] == ' ':
            last_val_non_empty = next(s for s in non_save if s)
            self.max_data_col  = len(non_save) - non_save[::-1].index(last_val_non_empty)
        else:
            self.max_data_col = len(non_save)


def check_vessel_name(vessel_name):
    " check the vessel_name is known "
    ships = ship_callsign_list()
    if vessel_name not in ships:
        warnings.simplefilter('default', UserWarning)
        warnings.warn('Vessel \'%s\' is not in AODN platform vocabulary' % vessel_name)
        return False
    else:
        return True


def create_filename_output(metadata, data):
    """ return a filename following the IMOS convention without the extension
    if absorption or ac9, data is a tupple; [0] is a df, [1] is a dict
    """

    input_filename = metadata['filename_input']
    date_created   = datetime.now().strftime("%Y%m%dT%H%M%SZ")

    if 'pigment' in input_filename:
        data_type = 'pigment'
        time_values = data.index.values

    elif 'absorption' in input_filename:
        time_values = data[1]['Dates']
        if 'aph' in metadata['varatts_col']:
            data_type = 'absorption-phytoplankton'
        elif 'ag' in metadata['varatts_col']:
            data_type = 'absorption-CDOM'
        elif 'ad' in metadata['varatts_col']:
            data_type = 'absorption-non-algal-detritus'
        elif 'ap' in metadata['varatts_col']:
            data_type = 'absorption-phytoplankton-non-algal-detritus'
        else:
            _error('Absorption Variable is unknown')

    elif 'TSS' in input_filename:
        data_type = 'suspended_matter'
        time_values = data.index.values
    elif 'ac9' in input_filename:
        time_values = data[1]['Dates']
        data_type = 'absorption-total-AC9'
    elif 'hs6' in input_filename:
        time_values = data[1]['Dates']
        data_type = 'backscattering-HS-6'
    else:
        _error('Unknown file type. Not pigment, absorption, TSS or AC9 HS6 file')

    cruise_id = metadata['gatts']['cruise_id'].strip().replace(' ', '_').replace('/', '-')
    if 'ac9' in input_filename or 'hs6' in input_filename:
        station_code = np.unique(data[1]['Station_Code'])[0]
        cruise_id = '%s-%s' % (cruise_id, station_code)

    date_start = pd.to_datetime(time_values).min().strftime("%Y%m%dT%H%M%SZ")
    date_end   = pd.to_datetime(time_values).max().strftime("%Y%m%dT%H%M%SZ")

    return 'IMOS_SRS-OC-BODBAW_X_%s_%s-%s_FV02_END-%s_C-%s' % (date_start,
                                                               cruise_id,
                                                               data_type,
                                                               date_end,
                                                               date_created)


def create_ac9_hs6_nc(metadata, data, output_folder):
    """ create a netcdf file for AC9/HS6 instrument data """
    netcdf_filepath   = os.path.join(output_folder, "%s.nc" % create_filename_output(metadata, data))
    output_netcdf_obj = Dataset(netcdf_filepath, "w", format="NETCDF4")

    data_dict = data[1]
    data_df = data[0]

    # read gatts from input, add them to output. Some gatts will be overwritten
    input_gatts = metadata['gatts']
    check_vessel_name(input_gatts['vessel_name'])  # this raises a warning only
    if input_gatts['vessel_name'].strip() == '':
        input_gatts['vessel_name'] = 'UNKNOWN VESSEL'

    gatt_to_dispose = ['geospatial_lat_min', 'geospatial_lat_max', 'geospatial_lon_min',
                       'geospatial_lon_max', 'geospatial_vertical_min', 'geospatial_vertical_max',
                       'conventions', 'local_time_zone']

    for gatt in input_gatts.keys():
        if gatt not in gatt_to_dispose:
            if input_gatts[gatt] != '':
                setattr(output_netcdf_obj, gatt, input_gatts[gatt])
    setattr(output_netcdf_obj, 'input_xls_filename', os.path.basename(metadata['filename_input']))

    if 'local_time_zone' in input_gatts.keys():
        if input_gatts['local_time_zone'] != '':
            setattr(output_netcdf_obj, 'local_time_zone', np.float(input_gatts['local_time_zone']))

    output_netcdf_obj.date_created            = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
    output_netcdf_obj.geospatial_vertical_min = min(data_dict['Depth'])
    output_netcdf_obj.geospatial_vertical_max = max(data_dict['Depth'])

    output_netcdf_obj.createDimension("obs", data_df.shape[0])
    output_netcdf_obj.createDimension("station", len(np.unique(data_dict['Station_Code'])))
    output_netcdf_obj.createDimension('name_strlen', 50)
    output_netcdf_obj.createDimension('wavelength', len(np.unique(data_dict['Wavelength'])))

    # a profile is defined by a time station combo. 2 profiles at the same time
    # but at a different location can exist. In order to find the unique
    # profiles, the unique values of a string array of 'time-station' is counted
    time_station_arr = ['%s_%s' % (a, b) for a, b in zip(data_dict['Dates'], data_dict['Station_Code'])]
    len_prof = len(np.unique(time_station_arr))
    output_netcdf_obj.createDimension("profile", len_prof)

    var_time         = output_netcdf_obj.createVariable("TIME", "d", "profile", fill_value=get_imos_parameter_info('TIME', '_FillValue'))
    var_lat          = output_netcdf_obj.createVariable("LATITUDE", "f", "station", fill_value=get_imos_parameter_info('LATITUDE', '_FillValue'))
    var_lon          = output_netcdf_obj.createVariable("LONGITUDE", "f", "station", fill_value=get_imos_parameter_info('LONGITUDE', '_FillValue'))
    var_station_name = output_netcdf_obj.createVariable("station_name", "S1", (u'station', u'name_strlen'))
    var_station_idx  = output_netcdf_obj.createVariable("station_index", "i4", "profile")
    var_profile      = output_netcdf_obj.createVariable("profile", "i4", "profile")
    var_rowsize      = output_netcdf_obj.createVariable("row_size", "i4", "profile")
    var_depth        = output_netcdf_obj.createVariable("DEPTH", "f", "obs", fill_value=get_imos_parameter_info('DEPTH', '_FillValue'))
    var_wavelength   = output_netcdf_obj.createVariable("wavelength", "f", "wavelength")

    # wavelength
    var                   = 'Wavelength'
    wavelength_val_sorted = np.sort(np.unique(data_dict['Wavelength']))
    var_wavelength[:]     = wavelength_val_sorted
    if metadata['varatts_row'][var]['IMOS long_name'] != '':
        setattr(var_wavelength, 'long_name', metadata['varatts_row'][var]['IMOS long_name'])
    if metadata['varatts_row'][var]['Units'] != '':
        setattr(var_wavelength, 'units', metadata['varatts_row'][var]['Units'])
    if metadata['varatts_row'][var]['Comments'] != '':
        setattr(var_wavelength, 'comments', metadata['varatts_row'][var]['Comments'])
    if metadata['varatts_row'][var]['CF standard_name'] != '':
        setattr(var_wavelength, 'standard_name', metadata['varatts_row'][var]['CF standard_name'])

    for var in np.unique(data_dict['main_var_name']):
        output_netcdf_obj.createVariable(var, "d", ("obs", "wavelength"), fill_value=metadata['varatts_col'][var]['Fill value'])
        if metadata['varatts_col'][var]['IMOS long_name'] != '':
            setattr(output_netcdf_obj[var], 'long_name', metadata['varatts_col'][var]['IMOS long_name'])
        if metadata['varatts_col'][var]['Units'] != '':
            setattr(output_netcdf_obj[var], 'units', metadata['varatts_col'][var]['Units'])
        if metadata['varatts_col'][var]['Comments'] != '':
            setattr(output_netcdf_obj[var], 'comments', metadata['varatts_col'][var]['Comments'])
        if metadata['varatts_col'][var]['CF standard_name'] != '':
            setattr(output_netcdf_obj[var], 'standard_name', metadata['varatts_col'][var]['CF standard_name'])
        setattr(output_netcdf_obj[var], 'coordinates', 'wavelength')

    for i, var in enumerate(data_dict['main_var_name']):
        var = data_dict['main_var_name'][i]
        idx_wavelength = wavelength_val_sorted.tolist().index(data_dict['Wavelength'][i])
        output_netcdf_obj[var][:, idx_wavelength] = np.array(data_df[i])

    # Continuous ragged array representation of Stations netcdf 1.5
    # add gatts and variable attributes as stored in config files
    conf_file_generic = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
    generate_netcdf_att(output_netcdf_obj, conf_file_generic, conf_file_point_of_truth=True)

    # lat lon depth
    _, idx_station_uniq = np.unique(data_dict['Station_Code'], return_index=True)
    idx_station_uniq.sort()
    var_lat[:]          = np.array(data_dict['Latitude'])[idx_station_uniq]
    var_lon[:]          = np.array(data_dict['Longitude'])[idx_station_uniq]
    var_depth[:]        = data_dict['Depth']
    var_depth.positive  = 'down'

    # time
    _, idx_time_station_uniq = np.unique(time_station_arr, return_index=True)
    idx_time_station_uniq.sort()
    time_values      = (data_dict['Dates'][idx_time_station_uniq]).to_pydatetime()
    time_val_dateobj = date2num(time_values, output_netcdf_obj['TIME'].units, output_netcdf_obj['TIME'].calendar)
    var_time[:]      = time_val_dateobj

    # stations
    var_station_name[:] = stringtochar(np.array(data_dict['Station_Code'], 'S50')[np.sort(idx_station_uniq)])

    # compute number of observations per profile
    if len_prof == 1:
        var_rowsize[:] = data_df.shape[0]
    else:
        n_obs_per_prof = []
        for i in range(len_prof - 1):
            n_obs_per_prof.append(idx_time_station_uniq[i + 1] - idx_time_station_uniq[i])
        n_obs_per_prof.append(data_df.shape[1] - idx_time_station_uniq[-1])
        var_rowsize[:] = n_obs_per_prof

    # compute association between profile number and station name
    # which station this profile is for
    aa = np.array(data_dict['Station_Code'])[idx_station_uniq].tolist()
    bb = np.array(data_dict['Station_Code'])[idx_time_station_uniq].tolist()
    var_station_idx[:] = [aa.index(b) + 1 for b in bb]

    # profile
    var_profile[:] = range(1, len_prof + 1)

    output_netcdf_obj.geospatial_vertical_min = output_netcdf_obj['DEPTH'][:].min()
    output_netcdf_obj.geospatial_vertical_max = output_netcdf_obj['DEPTH'][:].max()
    output_netcdf_obj.geospatial_lat_min      = output_netcdf_obj['LATITUDE'][:].min()
    output_netcdf_obj.geospatial_lat_max      = output_netcdf_obj['LATITUDE'][:].max()
    output_netcdf_obj.geospatial_lon_min      = output_netcdf_obj['LONGITUDE'][:].min()
    output_netcdf_obj.geospatial_lon_max      = output_netcdf_obj['LONGITUDE'][:].max()
    output_netcdf_obj.time_coverage_start     = min(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')
    output_netcdf_obj.time_coverage_end       = max(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')

    output_netcdf_obj.close()
    return netcdf_filepath


def create_absorption_nc(metadata, data, output_folder):
    """ create a netcdf file for absorption data """
    netcdf_filepath   = os.path.join(output_folder, "%s.nc" % create_filename_output(metadata, data))
    output_netcdf_obj = Dataset(netcdf_filepath, "w", format="NETCDF4")

    data_dict = data[1]
    data_df = data[0]

    # read gatts from input, add them to output. Some gatts will be overwritten
    input_gatts = metadata['gatts']
    check_vessel_name(input_gatts['vessel_name'])  # this raises a warning only
    if input_gatts['vessel_name'].strip() == '':
        input_gatts['vessel_name'] = 'UNKNOWN VESSEL'

    gatt_to_dispose = ['geospatial_lat_min', 'geospatial_lat_max', 'geospatial_lon_min',
                       'geospatial_lon_max', 'geospatial_vertical_min', 'geospatial_vertical_max',
                       'conventions', 'local_time_zone']

    for gatt in input_gatts.keys():
        if gatt not in gatt_to_dispose:
            if input_gatts[gatt] != '':
                setattr(output_netcdf_obj, gatt, input_gatts[gatt])
    setattr(output_netcdf_obj, 'input_xls_filename', os.path.basename(metadata['filename_input']))

    if 'local_time_zone' in input_gatts.keys():
        if input_gatts['local_time_zone'] != '':
            setattr(output_netcdf_obj, 'local_time_zone', np.float(input_gatts['local_time_zone']))

    output_netcdf_obj.date_created            = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
    output_netcdf_obj.geospatial_vertical_min = min(data_dict['Depth'])
    output_netcdf_obj.geospatial_vertical_max = max(data_dict['Depth'])

    output_netcdf_obj.createDimension("obs", data_df.shape[1])
    output_netcdf_obj.createDimension("station", len(np.unique(data_dict['Station_Code'])))
    output_netcdf_obj.createDimension('name_strlen', 50)
    output_netcdf_obj.createDimension('wavelength', data_df.shape[0])

    # a profile is defined by a time station combo. 2 profiles at the same time
    # but at a different location can exist. In order to find the unique
    # profiles, the unique values of a string array of 'time-station' is counted
    time_station_arr = ['%s_%s' % (a, b) for a, b in zip(data_dict['Dates'], data_dict['Station_Code'])]
    len_prof         = len(np.unique(time_station_arr))
    output_netcdf_obj.createDimension("profile", len_prof)

    var_time         = output_netcdf_obj.createVariable("TIME", "d", "profile", fill_value=get_imos_parameter_info('TIME', '_FillValue'))
    var_lat          = output_netcdf_obj.createVariable("LATITUDE", "f", "station", fill_value=get_imos_parameter_info('LATITUDE', '_FillValue'))
    var_lon          = output_netcdf_obj.createVariable("LONGITUDE", "f", "station", fill_value=get_imos_parameter_info('LONGITUDE', '_FillValue'))
    var_station_name = output_netcdf_obj.createVariable("station_name", "S1", (u'station', u'name_strlen'))
    var_station_idx  = output_netcdf_obj.createVariable("station_index", "i4", "profile")
    var_profile      = output_netcdf_obj.createVariable("profile", "i4", "profile")
    var_rowsize      = output_netcdf_obj.createVariable("row_size", "i4", "profile")
    var_depth        = output_netcdf_obj.createVariable("DEPTH", "f", "obs", fill_value=get_imos_parameter_info('DEPTH', '_FillValue'))
    var_wavelength   = output_netcdf_obj.createVariable("wavelength", "f", "wavelength")

    var = data_dict['main_var_name'][0]
    output_netcdf_obj.createVariable(var, "d", ("obs", "wavelength"), fill_value=metadata['varatts_col'][var]['Fill value'])
    if metadata['varatts_col'][var]['IMOS long_name'] != '':
        setattr(output_netcdf_obj[var], 'long_name', metadata['varatts_col'][var]['IMOS long_name'])
    if metadata['varatts_col'][var]['Units'] != '':
        setattr(output_netcdf_obj[var], 'units', metadata['varatts_col'][var]['Units'])
    if metadata['varatts_col'][var]['Comments'] != '':
        setattr(output_netcdf_obj[var], 'comments', metadata['varatts_col'][var]['Comments'])
    if metadata['varatts_col'][var]['CF standard_name'] != '':
        setattr(output_netcdf_obj[var], 'standard_name', metadata['varatts_col'][var]['CF standard_name'])

    data_val                  = data_df.transpose()
    output_netcdf_obj[var][:] = np.array(data_val.values)

    # Contigious ragged array representation of Stations netcdf 1.5
    # add gatts and variable attributes as stored in config files
    conf_file_generic = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
    generate_netcdf_att(output_netcdf_obj, conf_file_generic, conf_file_point_of_truth=True)

    # lat lon depth
    _, idx_station_uniq = np.unique(data_dict['Station_Code'], return_index=True)
    idx_station_uniq.sort()
    var_lat[:]          = np.array(data_dict['Latitude'])[idx_station_uniq]
    var_lon[:]          = np.array(data_dict['Longitude'])[idx_station_uniq]
    var_depth[:]        = data_dict['Depth']
    var_depth.positive  = 'down'

    # time
    _, idx_time_station_uniq = np.unique(time_station_arr, return_index=True)
    idx_time_station_uniq.sort()
    time_values      = (data_dict['Dates'][idx_time_station_uniq]).to_pydatetime()
    time_val_dateobj = date2num(time_values, output_netcdf_obj['TIME'].units, output_netcdf_obj['TIME'].calendar)
    var_time[:]      = time_val_dateobj

    # wavelength
    var = 'Wavelength'
    var_wavelength[:] = data_dict['Wavelength']
    if metadata['varatts_col'][var]['IMOS long_name'] != '':
        setattr(var_wavelength, 'long_name', metadata['varatts_col'][var]['IMOS long_name'])
    if metadata['varatts_col'][var]['Units'] != '':
        setattr(var_wavelength, 'units', metadata['varatts_col'][var]['Units'])
    if metadata['varatts_col'][var]['Comments'] != '':
        setattr(var_wavelength, 'comments', metadata['varatts_col'][var]['Comments'])
    if metadata['varatts_col'][var]['CF standard_name'] != '':
        setattr(var_wavelength, 'standard_name', metadata['varatts_col'][var]['CF standard_name'])

    # stationss
    var_station_name[:] = stringtochar(np.array(data_dict['Station_Code'], 'S50')[np.sort(idx_station_uniq)])

    # compute number of observations per profile
    if len_prof == 1:
        var_rowsize[:] = data.shape[1]
    else:
        n_obs_per_prof = []
        for i in range(len_prof - 1):
            n_obs_per_prof.append(idx_time_station_uniq[i + 1] - idx_time_station_uniq[i])
        n_obs_per_prof.append(data_df.shape[1] - idx_time_station_uniq[-1])

        var_rowsize[:] = n_obs_per_prof

    # compute association between profile number and station name
    # which station this profile is for
    aa = np.array(data_dict['Station_Code'])[idx_station_uniq].tolist()
    bb = np.array(data_dict['Station_Code'])[idx_time_station_uniq].tolist()
    var_station_idx[:] = [aa.index(b) + 1 for b in bb]

    # profile
    var_profile[:] = range(1, len_prof + 1)

    output_netcdf_obj.geospatial_vertical_min = output_netcdf_obj['DEPTH'][:].min()
    output_netcdf_obj.geospatial_vertical_max = output_netcdf_obj['DEPTH'][:].max()
    output_netcdf_obj.geospatial_lat_min      = output_netcdf_obj['LATITUDE'][:].min()
    output_netcdf_obj.geospatial_lat_max      = output_netcdf_obj['LATITUDE'][:].max()
    output_netcdf_obj.geospatial_lon_min      = output_netcdf_obj['LONGITUDE'][:].min()
    output_netcdf_obj.geospatial_lon_max      = output_netcdf_obj['LONGITUDE'][:].max()
    output_netcdf_obj.time_coverage_start     = min(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')
    output_netcdf_obj.time_coverage_end       = max(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')

    output_netcdf_obj.close()
    return netcdf_filepath


def create_pigment_tss_nc(metadata, data, output_folder):
    """ create a netcdf file for pigment or TSS data """
    netcdf_filepath   = os.path.join(output_folder, "%s.nc" % create_filename_output(metadata, data))
    output_netcdf_obj = Dataset(netcdf_filepath, "w", format="NETCDF4")

    # read gatts from input, add them to output. Some gatts will be overwritten
    input_gatts = metadata['gatts']
    check_vessel_name(input_gatts['vessel_name'])  # this raises a warning only
    if input_gatts['vessel_name'].strip() == '':
        input_gatts['vessel_name'] = 'UNKNOWN VESSEL'

    gatt_to_dispose = ['geospatial_lat_min', 'geospatial_lat_max', 'geospatial_lon_min',
                       'geospatial_lon_max', 'geospatial_vertical_min', 'geospatial_vertical_max',
                       'conventions', 'local_time_zone']

    for gatt in input_gatts.keys():
        if gatt not in gatt_to_dispose:
            if input_gatts[gatt] != '':
                setattr(output_netcdf_obj, gatt, input_gatts[gatt])
    setattr(output_netcdf_obj, 'input_xls_filename', os.path.basename(metadata['filename_input']))

    if 'local_time_zone' in input_gatts.keys():
        if input_gatts['local_time_zone'] != '':
            setattr(output_netcdf_obj, 'local_time_zone', np.float(input_gatts['local_time_zone']))

    output_netcdf_obj.date_created            = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
    output_netcdf_obj.geospatial_vertical_min = data.Depth.min()
    output_netcdf_obj.geospatial_vertical_max = data.Depth.max()

    output_netcdf_obj.createDimension("obs", data.shape[0])
    output_netcdf_obj.createDimension("station", len(data.Station_Code.unique()))
    output_netcdf_obj.createDimension('name_strlen', 50)

    # a profile is defined by a time station combo. 2 profiles at the same time
    # but at a different location can exist. In order to find the unique
    # profiles, the unique values of a string array of 'time-station' is counted
    time_station_arr = ['%s_%s' % (a, b) for a, b in zip(data.index, data.Station_Code.values)]
    len_prof         = len(np.unique(time_station_arr))
    output_netcdf_obj.createDimension("profile", len_prof)

    var_time         = output_netcdf_obj.createVariable("TIME", "d", "profile", fill_value=get_imos_parameter_info('TIME', '_FillValue'))
    var_lat          = output_netcdf_obj.createVariable("LATITUDE", "f4", "station", fill_value=get_imos_parameter_info('LATITUDE', '_FillValue'))
    var_lon          = output_netcdf_obj.createVariable("LONGITUDE", "f4", "station", fill_value=get_imos_parameter_info('LONGITUDE', '_FillValue'))
    var_station_name = output_netcdf_obj.createVariable("station_name", "S1", (u'station', u'name_strlen'))
    var_station_idx  = output_netcdf_obj.createVariable("station_index", "i4", "profile")
    var_profile      = output_netcdf_obj.createVariable("profile", "i4", "profile")
    var_rowsize      = output_netcdf_obj.createVariable("row_size", "i4", "profile")
    var_depth        = output_netcdf_obj.createVariable("DEPTH", "f4", "obs", fill_value=get_imos_parameter_info('DEPTH', '_FillValue'))

    var = 'DEPTH'
    if metadata['varatts']['Depth']['Comments'] != '' or metadata['varatts']['Depth']['Comments'] != 'positive down':
        setattr(output_netcdf_obj[var], 'comments', metadata['varatts']['Depth']['Comments'].replace('positive down', ''))

    # creation of rest of variables
    var_to_dispose = ['Latitude', 'Longitude', 'Depth', 'Time', 'Station_Code']
    for var in data.columns:
        if var not in var_to_dispose:
            if metadata['varatts'][var]['Fill value'] == '':
                fillvalue = -999
            else:
                fillvalue = metadata['varatts'][var]['Fill value']

            output_netcdf_obj.createVariable(var, "d", "obs", fill_value=fillvalue)
            if metadata['varatts'][var]['IMOS long_name'] != '':
                setattr(output_netcdf_obj[var], 'long_name', metadata['varatts'][var]['IMOS long_name'])
            if metadata['varatts'][var]['Units'] != '':
                setattr(output_netcdf_obj[var], 'units', metadata['varatts'][var]['Units'])
            if metadata['varatts'][var]['Comments'] != '':
                setattr(output_netcdf_obj[var], 'comments', metadata['varatts'][var]['Comments'])

            # SPM is set wrongly as a standard_name is original xls files
            if 'SPM' not in var:
                if metadata['varatts'][var]['CF standard_name'] != '':
                    setattr(output_netcdf_obj[var], 'standard_name', metadata['varatts'][var]['CF standard_name'])

            if 'Sample_Number' in var:
                setattr(output_netcdf_obj[var], 'units', 1)

            if np.dtype(data[var]) == 'O':
                os.remove(netcdf_filepath)
                _error('Incorrect values for variable \"%s\"' % var)
            output_netcdf_obj[var][:] = np.array(data[var].values).astype(np.double)

    # Contigious ragged array representation of Stations netcdf 1.5
    # add gatts and variable attributes as stored in config files
    conf_file_generic = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
    generate_netcdf_att(output_netcdf_obj, conf_file_generic, conf_file_point_of_truth=True)

    # lat lon depth
    _, idx_station_uniq = np.unique(data.Station_Code, return_index=True)
    idx_station_uniq.sort()
    var_lat[:]          = data.Latitude.values[idx_station_uniq].astype(np.float)
    var_lon[:]          = data.Longitude.values[idx_station_uniq].astype(np.float)
    if np.dtype(data.Depth) == 'O':
        try:
            var_depth[:] = data.Depth.values.astype(np.float)
        except ValueError:
            os.remove(netcdf_filepath)
            _error('Incorrect depth value')
    else:
        var_depth[:]       = data.Depth.values.astype(np.float)
    var_depth.positive = 'down'

    # time
    _, idx_time_station_uniq = np.unique(time_station_arr, return_index=True)
    idx_time_station_uniq.sort()
    time_values      = (data.index[idx_time_station_uniq]).to_pydatetime()
    time_val_dateobj = date2num(time_values, output_netcdf_obj['TIME'].units, output_netcdf_obj['TIME'].calendar)
    var_time[:]      = time_val_dateobj.astype(np.double)

    # station
    var_station_name[:] = stringtochar(np.array(data.Station_Code.values[idx_station_uniq], 'S50'))

    # compute number of observations per profile
    if len_prof == 1:
        var_rowsize[:] = data.shape[0]
    else:
        n_obs_per_prof = []
        for i in range(len_prof - 1):
            n_obs_per_prof.append(idx_time_station_uniq[i + 1] - idx_time_station_uniq[i])
        n_obs_per_prof.append(len(data.index.values) - idx_time_station_uniq[-1])

        var_rowsize[:] = n_obs_per_prof

    # compute association between profile number and station name
    # which station this profile is for
    aa = np.array(data.Station_Code)[idx_station_uniq].tolist()
    bb = np.array(data.Station_Code)[idx_time_station_uniq].tolist()
    var_station_idx[:] = [aa.index(b) + 1 for b in bb]

    # profile
    var_profile[:] = range(1, len_prof + 1)

    output_netcdf_obj.geospatial_vertical_min = output_netcdf_obj['DEPTH'][:].min()
    output_netcdf_obj.geospatial_vertical_max = output_netcdf_obj['DEPTH'][:].max()
    output_netcdf_obj.geospatial_lat_min      = output_netcdf_obj['LATITUDE'][:].min()
    output_netcdf_obj.geospatial_lat_max      = output_netcdf_obj['LATITUDE'][:].max()
    output_netcdf_obj.geospatial_lon_min      = output_netcdf_obj['LONGITUDE'][:].min()
    output_netcdf_obj.geospatial_lon_max      = output_netcdf_obj['LONGITUDE'][:].max()
    output_netcdf_obj.time_coverage_start     = min(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')
    output_netcdf_obj.time_coverage_end       = max(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')

    output_netcdf_obj.close()
    return netcdf_filepath


def export_xls_to_csv(metadata, data, output_folder, sheetname=0):
    """export an xls file or sheet into a csv file"""
    csv_output_filepath = os.path.join(output_folder, "%s.csv" % create_filename_output(metadata, data))
    input_filename_path = metadata['filename_input']
    data_xls            = pd.read_excel(input_filename_path, sheetname, index_col=None, header=None)
    data_xls.to_csv(csv_output_filepath, encoding='utf-8', index=False, header=None)


def create_pigment_tss_plot(netcdf_file_path):
    """create a png from a pigment netcdf file"""
    plot_output_filepath = os.path.splitext(netcdf_file_path)[0] + '.png'
    dataset              = Dataset(netcdf_file_path)

    profiles          = dataset.variables['profile']
    n_obs_per_profile = dataset.variables['row_size']
    n_profiles        = len(profiles)

    if 'CPHL_a' in dataset.variables.keys():
        main_data = dataset.variables['CPHL_a']
    elif 'SPM' in dataset.variables.keys():
        main_data = dataset.variables['SPM']
    else:
        find_main_var_name = (set(dataset.variables.keys()) - set([u'TIME', u'LATITUDE', u'LONGITUDE', u'station_name', u'station_index', u'profile', u'row_size', u'DEPTH'])).pop()
        main_data = dataset.variables[find_main_var_name]

    fig = figure(num=None, figsize=(15, 10), dpi=80, facecolor='w', edgecolor='k')
    labels = []
    ylim([-1, max(dataset.variables['DEPTH'][:]) + 1])
    for i_prof in range(n_profiles):
        # we look for the observations indexes related to the choosen profile
        idx_obs_start = sum(n_obs_per_profile[0:i_prof])
        idx_obs_end   = idx_obs_start + n_obs_per_profile[i_prof] - 1
        idx_obs       = range(idx_obs_start, idx_obs_end + 1)

        main_var_val = main_data[idx_obs]  # for i_prof
        depth_val    = dataset.variables['DEPTH'][idx_obs]

        if len(main_var_val) == 1:
            scatter(main_var_val, depth_val)
        elif len(main_var_val) > 1:
            plot(main_var_val, depth_val, '--')#, c=np.random.rand(3, 1))
        else:
            scatter(main_var_val, depth_val, c=np.random.rand(3, 1))

        station_name = ''.join(ma.getdata(dataset.variables['station_name'][dataset.variables['station_index'][i_prof] - 1]))
        labels.append(station_name)

    gca().invert_yaxis()
    title('%s\nCruise: %s' % (dataset.source, dataset.cruise_id))
    xlabel('%s: %s in %s' % (main_data.name, main_data.long_name, main_data.units))
    ylabel('%s in %s; positive %s' % (dataset.variables['DEPTH'].long_name,
                                      dataset.variables['DEPTH'].units,
                                      dataset.variables['DEPTH'].positive))
    try:
        legend(labels, loc='upper left', prop=fontP, title='Station')
    except:
        pass

    savefig(plot_output_filepath)
    plt.close(fig)


def create_ac9_hs6_plot(netcdf_file_path):
    """create a png from a ac9/hs6 netcdf file"""
    plot_output_filepath = os.path.splitext(netcdf_file_path)[0] + '.png'
    dataset              = Dataset(netcdf_file_path)
    n_wavelength         = dataset.variables['wavelength'].shape[0]

    # look for main variable
    for varname in dataset.variables.keys():
        dim = dataset.variables[varname].dimensions
        if 'obs' in dim and 'wavelength' in dim:
            main_data = dataset.variables[varname]

    fig = figure(num=None, figsize=(15, 10), dpi=80, facecolor='w', edgecolor='k')
    labels = []
    # only one profile per file in AC9 HS6 files
    for i_wl in range(n_wavelength):
        main_var_val   = main_data[:, i_wl]  # for i_prof
        depth_val      = dataset.variables['DEPTH'][:]
        wavelength_val = dataset.variables['wavelength'][i_wl]
        plot(main_var_val, depth_val)#, c=np.random.rand(3, 1))
        labels.append('%s nm' % wavelength_val)

    station_name = ''.join(ma.getdata(dataset.variables['station_name'][dataset.variables['station_index'][0] - 1]))
    title('%s\nCruise: %s\n Station %s' % (dataset.source, dataset.cruise_id, station_name))
    gca().invert_yaxis()
    xlabel('%s: %s in %s' % (main_data.name, main_data.long_name, main_data.units))
    ylabel('%s in %s; positive %s' % (dataset.variables['DEPTH'].long_name,
                                      dataset.variables['DEPTH'].units,
                                      dataset.variables['DEPTH'].positive))
    legend(labels, loc='upper right', prop=fontP, title='Wavelength')
    savefig(plot_output_filepath)
    plt.close(fig)


def create_absorption_plot(netcdf_file_path):
    """create a png from an absorption netcdf file"""
    plot_output_filepath = os.path.splitext(netcdf_file_path)[0] + '.png'
    dataset              = Dataset(netcdf_file_path)

    profiles          = dataset.variables['profile']
    n_obs_per_profile = dataset.variables['row_size']
    n_profiles        = len(profiles)

    # look for main variable
    for varname in dataset.variables.keys():
        dim = dataset.variables[varname].dimensions
        if 'obs' in dim and 'wavelength' in dim:
            main_data = dataset.variables[varname]

    fig = figure(num=None, figsize=(15, 10), dpi=80, facecolor='w', edgecolor='k')
    labels = []
    for i_prof in range(n_profiles):
        # we look for the observations indexes related to the choosen profile
        # only depth 0 is plotted
        depth_to_plot = int(0)
        idx_obs_start = sum(n_obs_per_profile[0:i_prof])
        idx_obs_end   = idx_obs_start + n_obs_per_profile[i_prof] - 1
        idx_obs       = range(idx_obs_start, idx_obs_end + 1)

        main_var_val   = main_data[idx_obs]  # for i_prof
        depth_val      = dataset.variables['DEPTH'][idx_obs]
        depth_val      = np.array(depth_val).astype(int)
        wavelength_val = dataset.variables['wavelength'][:]
        if not any(depth_val == depth_to_plot):
            continue

        df = pd.DataFrame(main_var_val[depth_val == depth_to_plot][0].flatten(), index=wavelength_val)
        plot(df.index, df, '.')

        station_name = ''.join(ma.getdata(dataset.variables['station_name'][dataset.variables['station_index'][i_prof] - 1]))
        labels.append(station_name)

    title('%s\nCruise: %s\n Depth = %sm' % (dataset.source, dataset.cruise_id, depth_to_plot))
    ylabel('%s: %s in %s' % (main_data.name, main_data.long_name, main_data.units))
    xlabel('%s in %s' % (dataset.variables['wavelength'].long_name,
                         dataset.variables['wavelength'].units))
    legend(labels, loc='upper right', prop=fontP, title='Station')
    savefig(plot_output_filepath)
    plt.close(fig)


def process_excel_pigment_tss(input_file_path, output_folder):
    """ main to process pigment or tss xls files. will create NetCDF, CSV PNG"""
    data_obj = ReadXlsPigmentTSS(input_file_path)
    metadata = {'gatts': data_obj.dic_gatts(),
                'varatts': data_obj.dic_var_def(),
                'filename_input': input_file_path}
    data = data_obj.data_frame()

    netcdf_file_path = create_pigment_tss_nc(metadata, data, output_folder)
    create_pigment_tss_plot(netcdf_file_path)
    export_xls_to_csv(metadata, data, output_folder)


def process_excel_absorption(input_file_path, output_folder):
    """ main to process absorption xls files. will create NetCDF, CSV PNG"""
    for sheet_name in ['ag data', 'aph data', 'ad data', 'ap data']:
        data_obj = ReadXlsAbsorptionAC9HS6(input_file_path, sheetname=sheet_name)
        if data_obj.has_sheet():
            metadata = {'gatts': data_obj.dic_gatts(),
                        'varatts_row': data_obj.dic_var_rows_def(),
                        'varatts_col': data_obj.dic_var_cols_def(),
                        'filename_input': input_file_path}
            data = data_obj.data_frame_absorption()

            netcdf_file_path = create_absorption_nc(metadata, data, output_folder)
            create_absorption_plot(netcdf_file_path)
            export_xls_to_csv(metadata, data, output_folder, sheet_name)


def process_excel_ac9_hs6(input_file_path, output_folder):
    """ main to process ac9/hs6 xls files. will create NetCDF, CSV PNG"""
    data_obj = ReadXlsAbsorptionAC9HS6(input_file_path)
    if data_obj.has_sheet():
        metadata = {'gatts': data_obj.dic_gatts(),
                    'varatts_row': data_obj.dic_var_rows_def(),
                    'varatts_col': data_obj.dic_var_cols_def(),
                    'filename_input': input_file_path}
        data = data_obj.data_frame_ac9_hs6()

        netcdf_file_path = create_ac9_hs6_nc(metadata, data, output_folder)
        create_ac9_hs6_plot(netcdf_file_path)
        export_xls_to_csv(metadata, data, output_folder)


def process_bodbaw_file(input_file_path, output_folder=''):
    print input_file_path

    """ process a BODBAW XLS file and call appropriate sub function """
    if 'absorption' in input_file_path:
        process_excel_absorption(input_file_path, output_folder)
    elif 'pigment' in input_file_path or 'TSS' in input_file_path:
        process_excel_pigment_tss(input_file_path, output_folder)
    elif 'ac9' in input_file_path or 'hs6' in input_file_path:
        process_excel_ac9_hs6(input_file_path, output_folder)
    else:
        _error('Filename does not contain one of the following keywords, (absorption|pigment|TSS)')


def args():
    """ define input argument"""
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input-excel-path', type=str,
                        help="path to excel file or directory", default=None)
    parser.add_argument('-o', '--output-folder', nargs='?', default=1,
                        help="output directory of generated files")
    vargs = parser.parse_args()

    if vargs.output_folder == 1:
        vargs.output_folder = tempfile.mkdtemp(prefix='bodbaw_')

    if vargs.input_excel_path is None:
        msg = '%s not a valid path' % vargs.input_dir_path
        print >> sys.stderr, msg
        sys.exit(1)

    if not os.path.exists(vargs.input_excel_path):
        msg = '%s not a valid path' % vargs.input_dir_path
        print >> sys.stderr, msg
        sys.exit(1)

    if not os.path.exists(vargs.output_folder):
        os.makedirs(vargs.output_folder)

    return vargs


if __name__ == '__main__':
    vargs = args()
    global INPUT_EXCEL_PATH  # defined as glob to be used in exception

    if os.path.isfile(vargs.input_excel_path):
        INPUT_EXCEL_PATH = os.path.basename(vargs.input_excel_path)
        process_bodbaw_file(vargs.input_excel_path, vargs.output_folder)
        print vargs.output_folder

    elif os.path.isdir(vargs.input_excel_path) is not None:
        for f in os.listdir(vargs.input_excel_path):
            try:
                f = os.path.join(vargs.input_excel_path, f)
                INPUT_EXCEL_PATH = os.path.basename(f)

                process_bodbaw_file(f, vargs.output_folder)
                print vargs.output_folder
            except Exception, e:
                traceback.print_exc()



