#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import difflib
import os
import sys
import tempfile
from configparser import ConfigParser
from datetime import datetime

import numpy as np
import numpy.ma as ma
from netCDF4 import Dataset, date2num

from generate_netcdf_att import generate_netcdf_att, get_imos_parameter_info
from ship_callsign import ship_callsign_list
from imos_logging import IMOSLogging
from xbt_line_vocab import xbt_line_info


class XbtException(Exception):
    pass


def _error(message):
    " Raise an exception with the given message."
    raise XbtException('In File \"%s\":\n%s' % (NETCDF_FILE_PATH, message))


def _call_parser(conf_file):
    """ parse a config file """
    parser = ConfigParser()
    parser.optionxform = str  # to preserve case
    conf_file_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), conf_file)
    parser.read(conf_file_path)
    return parser


def invalid_to_ma_array(invalid_array, fillvalue=0):
    """
    returns a masked array from an invalid XBT variable
    """
    masked = []
    array  = []
    for val in invalid_array:
        val = [''.join(chr(x)) for x in bytearray(val)][0]
        val = val.replace(' ', '')
        if val == '':
            masked.append(True)
            array.append(np.inf)
        else:
            masked.append(False)
            array.append(int(val))

    array = ma.array(array, mask=masked, fill_value=fillvalue)
    array = ma.fix_invalid(array)
    array = ma.array(array).astype(int)
    return array


def temp_prof_info(netcdf_file_path):
    """
    retrieve profile info from input NetCDF: TODO: improve comments
    """
    with Dataset(netcdf_file_path, 'r', format='NETCDF4') as netcdf_file_obj:
        no_prof = netcdf_file_obj['No_Prof'][0]

        for i in range(0, no_prof):
            prof_type = ''.join(chr(x) for x in bytearray(netcdf_file_obj['Prof_Type'][:][i].data)).strip()
            if prof_type == 'TEMP':
                temp_prof = i
                break
        return no_prof, prof_type, temp_prof


def parse_gatts_nc(netcdf_file_path):
    """
    retrieve global attributes only for input NetCDF file
    """
    LOGGER.info('Parsing gatts from  %s' % netcdf_file_path)
    with Dataset(netcdf_file_path, 'r', format='NETCDF4') as netcdf_file_obj:

        no_prof, prof_type, temp_prof = temp_prof_info(netcdf_file_path)

        cruise_id    = ''.join(chr(x) for x in bytearray(netcdf_file_obj['Cruise_ID'][:].data)).strip()
        deep_depth   = netcdf_file_obj['Deep_Depth'][temp_prof]
        srfc_code_nc = netcdf_file_obj['SRFC_Code'][:]
        srfc_parm    = netcdf_file_obj['SRFC_Parm'][:]


        xbt_config = _call_parser('xbt_config')
        if 'SRFC_CODES' in xbt_config.sections():
            srfc_code_list = dict(xbt_config.items('SRFC_CODES'))
        else:
            _error('xbt_config file not valid')

        # read a list of srfc code defined in the srfc_code conf file. Create a
        # dictionary of matching values
        gatts = {}
        for i in range(len(srfc_code_nc)):
            srfc_code_iter = ''.join([chr(x) for x in bytearray(srfc_code_nc[i].data)]).rstrip('\x00')
            if srfc_code_iter in list(srfc_code_list.keys()):
                att_name = srfc_code_list[srfc_code_iter].split(',')[0]
                att_type = srfc_code_list[srfc_code_iter].split(',')[1]
                att_val  = ''.join([chr(x) for x in bytearray(srfc_parm[i].data)]).strip()
                if att_val.replace(' ', '') != '':
                    gatts[att_name] = att_val
                    try:
                        if att_type == 'float':
                            gatts[att_name] = float(gatts[att_name].replace(' ', ''))
                        elif att_type == 'int':
                                gatts[att_name] = int(gatts[att_name].replace(' ', ''))
                    except ValueError:
                        LOGGER.warning('"%s = %s" could not be converted to %s()' % (att_name, gatts[att_name], att_type.upper()))

            else:
                if srfc_code_iter != '':
                    LOGGER.warning('%s code is not defined in srfc_code conf file. Please edit conf' % srfc_code_iter)

        # cleaning
        att_name = 'XBT_probetype_fallrate_equation'
        if att_name in list(gatts.keys()):
            gatts[att_name] = ('See WMO Code Table 1770 for the information corresponding to the value: %s' % gatts[att_name])

        att_name = 'XBT_recorder_type'
        if att_name in list(gatts.keys()):
            gatts[att_name] = ('See WMO Code Table 4770 for the information corresponding to the value: %s' % gatts[att_name])

        att_name = 'XBT_height_launch_above_water_in_meters'
        if att_name in list(gatts.keys()):
            if gatts[att_name] > 30:
                LOGGER.warning('HTL$, xbt launch height attribute seems to be very high: %s meters' % gatts[att_name])

        gatts['geospatial_vertical_max'] = deep_depth.item(0)
        gatts['XBT_cruise_ID']           = cruise_id

        if INPUT_DIRNAME is None:
            gatts['XBT_input_filename'] = os.path.basename(netcdf_file_path)  # case when input is a file
        else:
            gatts['XBT_input_filename'] = netcdf_file_path.replace(os.path.dirname(INPUT_DIRNAME), '').strip('/')  # we keep the last folder name of the input as the 'database' folder

        # get xbt line information from config file
        xbt_line_conf_section = [s for s in xbt_config.sections() if gatts['XBT_line'] in s]
        xbt_alt_codes = [s for s in list(XBT_LINE_INFO.keys()) if XBT_LINE_INFO[s] is not None]  # alternative IMOS codes taken from vocabulary
        if xbt_line_conf_section != []:
            xbt_line_att = dict(xbt_config.items(xbt_line_conf_section[0]))
            gatts.update(xbt_line_att)
        elif gatts['XBT_line'] in xbt_alt_codes:
            xbt_line_conf_section = [s for s in xbt_config.sections() if XBT_LINE_INFO[gatts['XBT_line']] == s]
            xbt_line_att = dict(xbt_config.items(xbt_line_conf_section[0]))
            gatts.update(xbt_line_att)
        else:
            LOGGER.error('XBT line : "%s" is not defined in conf file(Please edit), or an alternative code has to be set up by AODN in vocabs.ands.org.au(contact AODN)' % gatts['XBT_line'])
            exit(1)

        return gatts


def parse_annex_nc(netcdf_file_path):
    LOGGER.info('Parsing annex from %s' % netcdf_file_path)
    with Dataset(netcdf_file_path, 'r', format='NETCDF4') as netcdf_file_obj:
        data_avail = netcdf_file_obj['Data_Avail'][0]
        dup_flag = netcdf_file_obj['Dup_Flag'][0]
        ident_code = netcdf_file_obj['Ident_Code'][:]

        no_prof, prof_type, temp_prof = temp_prof_info(netcdf_file_path)

        # previous values history. same indexes and dimensions of all following vars
        act_code = [''.join(chr(x) for x in bytearray(xx)).strip() for xx in netcdf_file_obj['Act_Code'][:].data if
                    bytearray(xx).strip()]
        act_parm = [''.join(chr(x) for x in bytearray(xx)).strip() for xx in netcdf_file_obj['Act_Parm'][:].data if
                    bytearray(xx).strip()]
        prc_code = [''.join(chr(x) for x in bytearray(xx)).strip() for xx in netcdf_file_obj['PRC_Code'][:].data if
                    bytearray(xx).strip()]
        prc_date = [''.join(chr(x) for x in bytearray(xx)).strip() for xx in netcdf_file_obj['PRC_Date'][:].data if
                    bytearray(xx).strip()]
        prc_date = [datetime.strptime(date, '%Y%m%d') for date in prc_date]
        aux_id = [_f for _f in netcdf_file_obj['Aux_ID'][:] if _f]  # depth value of modified act_parm var modified
        version_soft = [''.join(chr(x) for x in bytearray(xx)).strip() for xx in netcdf_file_obj['Version'][:].data if
                        bytearray(xx).strip()]
        previous_val = [float(x) for x in [''.join(chr(x) for x in bytearray(xx).strip()).rstrip('\x00') for xx in
                                           netcdf_file_obj['Previous_Val'][:]] if x]
        ident_code = [''.join(chr(x) for x in bytearray(xx)).strip() for xx in ident_code if bytearray(xx).strip()]

        annex = {}
        annex['dup_flag'] = dup_flag
        annex['ident_code'] = ident_code
        annex['data_avail'] = data_avail
        annex['act_code'] = act_code
        annex['act_parm'] = act_parm
        annex['aux_id'] = aux_id
        annex['prc_code'] = prc_code
        annex['prc_date'] = prc_date
        annex['version_soft'] = version_soft
        annex['no_prof'] = no_prof
        annex['prof_type'] = prof_type
        annex['previous_val'] = previous_val

        return annex


def parse_data_nc(netcdf_file_path):
    LOGGER.info('Parsing data from %s' % netcdf_file_path)
    with Dataset(netcdf_file_path, 'r', format='NETCDF4') as netcdf_file_obj:
        woce_date = netcdf_file_obj['woce_date'][0]
        woce_time = netcdf_file_obj['woce_time'][0]
        q_date_time = int(netcdf_file_obj['Q_Date_Time'][0])
        latitude = netcdf_file_obj['latitude'][0]
        longitude = netcdf_file_obj['longitude'][0]
        q_pos = netcdf_file_obj['Q_Pos'][0]

        no_prof, prof_type, temp_prof = temp_prof_info(netcdf_file_path)

        # position QC
        if q_pos == '1':
            q_pos = 1
        else:
            q_pos = 1  # We should have flags of '1' on the lat/long, as these have been QC'd. Although not explicit in the original netcdf files (Bec Cowley 03/2020)

        xbt_date = '%sT%s' % (woce_date, str(woce_time).zfill(6))  # add leading 0
        xbt_date = datetime.strptime(xbt_date, '%Y%m%dT%H%M%S')

        depth_press = netcdf_file_obj['Depthpress'][temp_prof, :]
        depth_press_flag = netcdf_file_obj['DepresQ'][temp_prof, :, 0].flatten()
        depth_press_flag = np.ma.masked_array(invalid_to_ma_array(depth_press_flag, fillvalue=0))
        if isinstance(netcdf_file_obj['Profparm'][temp_prof, 0, :, 0, 0], np.ma.MaskedArray):
            prof = np.ma.masked_where(netcdf_file_obj['Profparm'][temp_prof, 0, :, 0, 0].data > 50,
                                      netcdf_file_obj['Profparm'][temp_prof, 0, :, 0, 0])
        else:
            prof = np.ma.masked_where(netcdf_file_obj['Profparm'][temp_prof, 0, :, 0, 0] > 50,
                                      netcdf_file_obj['Profparm'][temp_prof, 0, :, 0, 0])
            prof.set_fill_value(-99.99)

        prof_flag = netcdf_file_obj['ProfQP'][temp_prof, 0, :, 0, 0].flatten()
        prof_flag = np.ma.masked_array(
            invalid_to_ma_array(prof_flag, fillvalue=99))  # replace masked values for IMOS IODE flags

        data = {}
        data['LATITUDE'] = latitude
        data['LATITUDE_quality_control'] = q_pos
        data['LONGITUDE'] = longitude
        data['LONGITUDE_quality_control'] = q_pos
        data['TIME'] = xbt_date
        data['TIME_quality_control'] = q_date_time

        if isinstance(depth_press, np.ma.MaskedArray):
            data['DEPTH'] = depth_press[
                ~ma.getmask(depth_press)].flatten()  # DEPTH is a dimension, so we remove mask values, ie FillValues
            data['DEPTH_quality_control'] = depth_press_flag[~ma.getmask(depth_press)].flatten()
            data['TEMP'] = prof[~ma.getmask(depth_press)].flatten()
            data['TEMP_quality_control'] = prof_flag[~ma.getmask(depth_press)].flatten()
        else:
            data['DEPTH'] = depth_press
            data['DEPTH_quality_control'] = depth_press_flag
            data['TEMP'] = prof
            data['TEMP_quality_control'] = prof_flag

        return data


def parse_edited_nc(netcdf_file_path):
    """ Read an edited XBT file written in an un-friendly NetCDF format
    global attributes, data and annex information are returned

    gatts, data, annex = parse_edited_nc(netcdf_file_path)
    """
    LOGGER.info('Parsing %s' % netcdf_file_path)

    gatts = parse_gatts_nc(netcdf_file_path)
    annex = parse_annex_nc(netcdf_file_path)
    data = parse_data_nc(netcdf_file_path)

    return gatts, data, annex


def is_xbt_prof_to_be_parsed(netcdf_file_path, keys_file_path):
    """"
    Check if an xbt ed or raw netcdf file should be converted by looking at the station_number existence in the
    *_keys.nc file for each database of profiles to convert
    """
    gatts = parse_gatts_nc(netcdf_file_path)
    keys_info = parse_keys_nc(keys_file_path)

    if gatts['XBT_uniqueid'] in keys_info['station_number']:
        return True
    else:
        return False


def create_filename_output(gatts, data):
    filename = 'XBT_T_%s_%s_FV01_ID-%s' % (data['TIME'].strftime('%Y%m%dT%H%M%SZ'), gatts['XBT_line'], gatts['XBT_uniqueid'])

    if data['TIME'] > datetime(2008, 0o1, 0o1):
        filename = 'IMOS_SOOP-%s' % filename

    if '/' in filename:
        LOGGER.error('The sign \'/\' is contained inside the NetCDF filename "%s". Likely '
                     'due to a slash in the XTB_line attribute. Please ammend '
                     'the XBT_line attribute in the config file for the XBT line "%s"'
                     % (filename, gatts['XBT_line']))
        exit(1)

    return filename


def check_nc_to_be_created(annex):
    """ different checks to make sure we want to create a netcdf for this profile
    """
    if annex['dup_flag'] == 'D':
        LOGGER.error('Profile not processed. Tagged as duplicate in original netcdf file')
        return False

    if 'TP' in annex['act_code'] or 'DU' in annex['act_code']:
        LOGGER.error('Profile not processed. Tagged as duplicate in original netcdf file')
        return False

#    if annex['no_prof'] > 1:
#        LOGGER.error('Profile not processed. No_Prof variable is greater than 0')
#        return False

    if annex['prof_type'] != 'TEMP':
        LOGGER.error('Profile not processed. Main variable is not TEMP')
        return False

    return True


def create_nc_history_list(annex):
    """ create the history netcdf attribute based on data values change"""
    xbt_config = _call_parser('xbt_config')
    if 'ACT_CODES' in xbt_config.sections():
        act_code_list = dict(xbt_config.items('ACT_CODES'))
    else:
        _error('xbt_config file not valid')

    history = []
    for idx, date in enumerate(annex['prc_date']):
        if annex['act_code'][idx] in act_code_list:
            act_code_def = act_code_list[annex['act_code'][idx]]
        else:
            act_code_def = annex['act_code'][idx]
            LOGGER.warning("ACT CODE \"%s\" is not defined. Please edit config file" % annex['act_code'][idx])

        history.append("%s - CSIRO QC Cookbook software version %s: "
                       "Previous value %s=%s at DEPTH=%s - "
                       "Action performed on parameter: %s(%s)\n" %
                       (date.strftime('%a %b %d %H:%M:%S %Y'),
                        annex['version_soft'][idx],
                        annex['act_parm'][idx],
                        annex['previous_val'][idx],
                        annex['aux_id'][idx],
                        annex['act_code'][idx],
                        act_code_def))

    return ''.join(history)


def generate_xbt_nc(gatts, data, annex, output_folder):
    """create an xbt profile"""
    netcdf_filepath = os.path.join(output_folder, "%s.nc" % create_filename_output(gatts, data))
    LOGGER.info('Creating output %s' % netcdf_filepath)

    output_netcdf_obj = Dataset(netcdf_filepath, "w", format="NETCDF4")
    # set global attributes
    for gatt_name in list(gatts.keys()):
        setattr(output_netcdf_obj, gatt_name, gatts[gatt_name])

    history_att = create_nc_history_list(annex)
    if history_att != '':
        setattr(output_netcdf_obj, 'history', history_att)

    # this will overwrite the value found in the original NetCDF file
    ships = SHIP_CALL_SIGN_LIST
    if gatts['Platform_code'] in ships:
        output_netcdf_obj.ship_name = ships[gatts['Platform_code']]
        output_netcdf_obj.Callsign  = gatts['Platform_code']
    elif difflib.get_close_matches(gatts['Platform_code'], ships, n=1, cutoff=0.8) != []:
        output_netcdf_obj.Callsign      = difflib.get_close_matches(gatts['Platform_code'], ships, n=1, cutoff=0.8)[0]
        output_netcdf_obj.Platform_code = output_netcdf_obj.Callsign
        output_netcdf_obj.ship_name     = ships[output_netcdf_obj.Callsign]
        LOGGER.warning('Vessel call sign %s seems to be wrong. Using his closest match to the AODN vocabulary: %s' % (gatts['Platform_code'], output_netcdf_obj.Callsign))
    else:
        LOGGER.warning('Vessel call sign %s is unknown in AODN vocabulary, Please contact info@aodn.org.au' % gatts['Platform_code'])

    output_netcdf_obj.date_created            = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(data['DEPTH'], np.ma.MaskedArray):
        output_netcdf_obj.geospatial_vertical_min = np.ma.MaskedArray.min(data['DEPTH']).item(0)
        output_netcdf_obj.geospatial_vertical_max = np.ma.MaskedArray.max(data['DEPTH']).item(0)
    else:
        output_netcdf_obj.geospatial_vertical_min = min(data['DEPTH'])
        output_netcdf_obj.geospatial_vertical_max = max(data['DEPTH'])

    output_netcdf_obj.geospatial_lat_min      = data['LATITUDE']
    output_netcdf_obj.geospatial_lat_max      = data['LATITUDE']
    output_netcdf_obj.geospatial_lon_min      = data['LONGITUDE']
    output_netcdf_obj.geospatial_lon_max      = data['LONGITUDE']
    output_netcdf_obj.time_coverage_start     = data['TIME'].strftime('%Y-%m-%dT%H:%M:%SZ')
    output_netcdf_obj.time_coverage_end       = data['TIME'].strftime('%Y-%m-%dT%H:%M:%SZ')

    output_netcdf_obj.createDimension('DEPTH', data['DEPTH'].size)
    output_netcdf_obj.createVariable("DEPTH", "f", "DEPTH")
    output_netcdf_obj.createVariable('DEPTH_quality_control', "b", "DEPTH")

    var_time = output_netcdf_obj.createVariable("TIME", "d", fill_value=get_imos_parameter_info('TIME', '_FillValue'))
    output_netcdf_obj.createVariable("TIME_quality_control", "b", fill_value=99)

    output_netcdf_obj.createVariable("LATITUDE", "f", fill_value=get_imos_parameter_info('LATITUDE', '_FillValue'))
    output_netcdf_obj.createVariable("LATITUDE_quality_control", "b", fill_value=99)

    output_netcdf_obj.createVariable("LONGITUDE", "f", fill_value=get_imos_parameter_info('LONGITUDE', '_FillValue'))
    output_netcdf_obj.createVariable("LONGITUDE_quality_control", "b", fill_value=99)

    output_netcdf_obj.createVariable("TEMP", "f", ["DEPTH"], fill_value=get_imos_parameter_info('TEMP', '_FillValue'))
    output_netcdf_obj.createVariable("TEMP_quality_control", "b", ["DEPTH"], fill_value=data['TEMP_quality_control'].fill_value)

    conf_file_generic = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
    generate_netcdf_att(output_netcdf_obj, conf_file_generic, conf_file_point_of_truth=True)

    for var in list(data.keys()):
        if var == 'TIME':
            time_val_dateobj = date2num(data['TIME'], output_netcdf_obj['TIME'].units, output_netcdf_obj['TIME'].calendar)
            var_time[:]      = time_val_dateobj
        else:
            if isinstance(data[var], np.ma.MaskedArray):
                output_netcdf_obj[var][:] = data[var].data
            else:
                output_netcdf_obj[var][:] = data[var]

    # default value for abstract
    if not hasattr(output_netcdf_obj, 'abstract'):
        setattr(output_netcdf_obj, 'abstract', output_netcdf_obj.title)

    output_netcdf_obj.close()
    return netcdf_filepath


def parse_keys_nc(keys_file_path):
    """
    input: path to *.keys.nc
    output: data dictionary containing unique values of station_number (to be used in edited and raw NetCDF to match
            with the SRFC_Parm value
    """
    with Dataset(keys_file_path, 'r', format='NETCDF4') as netcdf_file_obj:
        station_number = [''.join(chr(x) for x in bytearray(xx)).strip() for xx in netcdf_file_obj['stn_num'][:].data if
                          bytearray(xx).strip()]
        station_number = list(set(station_number))  # make sure we have a unique list of IDs. Sometimes they are repeated in the keys file (a fault in some of them)

        data = {}
        data['station_number'] = [int(x) for x in station_number]  # station_number values are integers
        return data


def args():
    """ define input argument"""
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input-xbt-campaign-path', type=str,
                        help="path to root folder containing *keys.nc and individual NetCDF's")
    parser.add_argument('-o', '--output-folder', nargs='?', default=1,
                        help="output directory of generated files")
    parser.add_argument('-l', '--log-file', nargs='?', default=1,
                        help="log directory")
    vargs = parser.parse_args()

    if vargs.output_folder == 1:
        vargs.output_folder = tempfile.mkdtemp(prefix='xbt_dm_')
    elif not os.path.isabs(os.path.expanduser(vargs.output_folder)):
        vargs.output_folder = os.path.join(os.getcwd(), vargs.output_folder)

    if vargs.log_file == 1:
        vargs.log_file = os.path.join(vargs.output_folder, 'xbt.log')
    else:
        if not os.path.exists(os.path.dirname(vargs.log_file)):
            os.makedirs(os.path.dirname(vargs.log_file))

    if not os.path.exists(vargs.input_xbt_campaign_path):
        msg = '%s not a valid path' % vargs.input_xbt_campaign_path
        print(msg, file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(vargs.output_folder):
        os.makedirs(vargs.output_folder)

    return vargs


def process_xbt_file(xbt_file_path, output_folder):
    gatts, data, annex = parse_edited_nc(xbt_file_path)
    if check_nc_to_be_created(annex):
        return generate_xbt_nc(gatts, data, annex, output_folder)
    return


def global_vars(vargs):
    global LOGGER
    logging = IMOSLogging()
    LOGGER  = logging.logging_start(vargs.log_file)

    global NETCDF_FILE_PATH  # defined as glob to be used in exception

    global SHIP_CALL_SIGN_LIST
    SHIP_CALL_SIGN_LIST = ship_callsign_list()  # AODN CALLSIGN vocabulary

    global XBT_LINE_INFO
    XBT_LINE_INFO = xbt_line_info()

    global INPUT_DIRNAME  # in the case we're processing a directory full of NetCDF's and not ONE NetCDF only
    INPUT_DIRNAME = None


if __name__ == '__main__':
    os.umask(0o002)
    vargs = args()
    global_vars(vargs)

    # find the keys.nc file inside the input folder (root folder)
    keys_file_path = None
    for (_, _, filenames) in os.walk(vargs.input_xbt_campaign_path):
        if len(filenames) > 0:
            if filenames[0].endswith('_keys.nc'):
                keys_file_path = os.path.join(vargs.input_xbt_campaign_path, filenames[0])
                break

    if keys_file_path is None:
        msg = ('No *_keys.nc in input folder %s\nProcess aborted' % vargs.input_xbt_campaign_path)
        print(msg, file=sys.stderr)
        sys.exit(1)

    edited_nc = [os.path.join(dp, f) for dp, dn, filenames in os.walk(vargs.input_xbt_campaign_path)
                 for f in filenames if f.endswith('ed.nc')]

    for f in edited_nc:
        INPUT_DIRNAME = vargs.input_xbt_campaign_path
        NETCDF_FILE_PATH = f

        if is_xbt_prof_to_be_parsed(f, keys_file_path):
            path = process_xbt_file(f, vargs.output_folder)
        else:
            LOGGER.warning('file %s is not processed as not part of _keys.nc' % f)
