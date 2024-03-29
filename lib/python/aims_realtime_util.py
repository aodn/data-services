""" set of tools to
- parse AIMS RSS feed web pages
- create a list of monthly timestamps to download
- generate URL to download (with regards to what has already been downloaded
- unzip and modify NetCDF files so they pass both CF and IMOS checker

data.aims.gov.au/gbroosdata/services/rss/netcdf/level0/1    -> FAIMMS
data.aims.gov.au/gbroosdata/services/rss/netcdf/level0/100  -> SOOP TRV
data.aims.gov.au/gbroosdata/services/rss/netcdf/level0/300  -> NRS DARWIN YONGALA BEAGLE

author Laurent Besnard, laurent.besnard@utas.edu.au
"""
import datetime
import glob
import json
import logging
import os
import pickle
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
import zipfile
from time import gmtime, strftime

import dotenv
import numpy
import requests
from six.moves.urllib.request import urlopen
from six.moves.urllib_error import URLError

try:
    from functools import lru_cache
except ImportError:
    from functools32 import lru_cache
from netCDF4 import Dataset, date2num, num2date

from retrying import retry
from logging.handlers import TimedRotatingFileHandler


#####################
# Logging Functions #
#####################


def logging_aims():
    """ start logging using logging python library
    output:
       logger - similar to a file handler
    """
    wip_path = os.environ.get('data_wip_path')
    # this is used for unit testing as data_wip_path env would not be set
    if wip_path is None:
        wip_path = tempfile.mkdtemp()

    logging_format = "%(asctime)s — %(name)s — %(levelname)s — %(funcName)s:%(lineno)d — %(message)s"

    # set up logging to file
    tmp_filename = tempfile.mkstemp('.log', 'aims_data_download_')[1]
    log_path = os.path.join(wip_path, 'aims.log')
    logging.basicConfig(level=logging.INFO,
                        format=logging_format,
                        filename=tmp_filename,
                        filemode='a+')

    # rotate logs every Day, and keep only the last 5 log files
    logHandler = TimedRotatingFileHandler(log_path,
                                          when="D",
                                          interval=1,
                                          backupCount=5,  # backupCount files will be kept
                                          )
    logHandler.setFormatter(logging.Formatter(logging_format))
    logHandler.setLevel(logging.DEBUG)
    logging.getLogger('').addHandler(logHandler)

    # define a Handler which writes DEBUG messages to the sys.stderr
    logFormatter = logging.Formatter(logging_format)
    consoleHandler = logging.StreamHandler()
    consoleHandler.setLevel(logging.INFO)
    consoleHandler.setFormatter(logFormatter)

    # add the console handler to the root logger
    logging.getLogger('').addHandler(consoleHandler)


####################
# Pickle Functions #
####################


def _pickle_filename(level_qc):
    """ returns the pickle filepath according to the QC level being processed
    input:
        level_qc(int) : 0 or 1
    output:
        picleQc_file(str) : pickle file path
    """
    wip_path = os.environ.get('data_wip_path')
    if wip_path is None:
        raise ValueError('data_wip_path enviromnent variable is not set')

    if level_qc == 0:
        pickle_qc_file = os.path.join(wip_path, 'aims_qc0.pickle')
    elif level_qc == 1:
        pickle_qc_file = os.path.join(wip_path, 'aims_qc1.pickle')

    return pickle_qc_file


def delete_channel_id_from_pickle(level_qc, channel_id):
    pickle_file = _pickle_filename(level_qc)
    with open(pickle_file, 'rb') as p_read:
        aims_xml_info = pickle.load(p_read)

    if channel_id in aims_xml_info.keys():
        del(aims_xml_info[channel_id])

    with open(pickle_file, 'wb') as p_write:
        pickle.dump(aims_xml_info, p_write)


def delete_platform_entries_from_pickle(level_qc, platform):
    """
    function to be called manually to facilitate the deletion of ALL platforms matching
    a certain string.

    This will not delete objects from S3 which has to be done semi-manually

    example:
        $ export data_wip_path=$WIP_DIR/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_download_temporary
        $ cd $DATA_SERVICES_DIR/lib/aims
        $ ipython
        In [0]: from realtime_util import delete_platform_entries_from_pickle
        In [1]: delete_platform_entries_from_pickle(0, 'Beagle')
        In [2]: delete_platform_entries_from_pickle(2, 'Beagle')
    """
    pickle_file = _pickle_filename(level_qc)
    with open(pickle_file, 'rb') as p_read:
        aims_xml_info = pickle.load(p_read)

    def delete_over_list_platform(aims_xml_info, platform):
        for index_platform, value in enumerate(aims_xml_info):
            if platform in value:
                for index_field in range(0, len(aims_xml_info)):
                    del(aims_xml_info[index_field][platform_name])
                aims_xml_info = delete_over_list_platform(aims_xml_info, platform)
        return aims_xml_info

    aims_xml_info_clean = delete_over_list_platform(aims_xml_info, platform)
    with open(pickle_file, 'wb') as p_write:
        pickle.dump(aims_xml_info_clean, p_write)


@retry(URLError, tries=10, delay=3, backoff=2)
def urlopen_with_retry(url):
    """ it will retry a maximum of 10 times, with an exponential backoff delay
    doubling each time, e.g. 3 seconds, 6 seconds, 12 seconds
    """
    return urlopen(url)


def save_channel_info(channel_id, aims_xml_info, level_qc, *last_downloaded_date_channel):
    """
     if channel_id has been successfuly processed, we write about it in a pickle file
     we write the last downloaded data date for each channel
     input:
        channel_id(str)       : channel_id to save information
        aims_xml_info(dict) : generated by parser_aims_xml
        level_qc(int)         : 0 or 1
        last_downloaded_date_channel is a variable argument, not used by soop trv
    """
    pickle_file = _pickle_filename(level_qc)
    last_downloaded_date = dict()
    # condition in case the pickle file already exists or not. In the first case,
    # aims_xml_info comes from the pickle, file, otherwise comes from the function arg
    if os.path.isfile(pickle_file):
        with open(pickle_file, 'rb') as p_read:
            aims_xml_info_file = pickle.load(p_read)
            last_downloaded_date = aims_xml_info_file

        if not last_downloaded_date_channel:
            # soop trv specific, vararg
            last_downloaded_date[channel_id] = aims_xml_info[channel_id]['thru_date']
        else:
            last_downloaded_date[channel_id] = last_downloaded_date_channel[0]

    else:
        if not last_downloaded_date_channel:
            # soop trv specific, vararg
            last_downloaded_date[channel_id] = aims_xml_info[channel_id]['thru_date']
        else:
            last_downloaded_date[channel_id] = last_downloaded_date_channel[0]

    with open(pickle_file, 'wb') as p_write:
        pickle.dump(last_downloaded_date, p_write)


def get_last_downloaded_date_channel(channel_id, level_qc, from_date):
    """ Retrieve the last date sucessfully downloaded for a channel """
    pickle_file = _pickle_filename(level_qc)  # different pickle per QC
    if os.path.isfile(pickle_file):
        with open(pickle_file, 'rb') as p_read:
            last_downloaded_date = pickle.load(p_read)

        if channel_id in last_downloaded_date.keys():  # check the channel is in the pickle file
            if last_downloaded_date[channel_id] is not None:
                return last_downloaded_date[channel_id]

    return from_date


def has_channel_already_been_downloaded(channel_id, level_qc):
    pickle_file = _pickle_filename(level_qc)  # different pickle per QC
    if os.path.isfile(pickle_file):
        with open(pickle_file, 'rb') as p_read:
            last_downloaded_date = pickle.load(p_read)

        if channel_id in last_downloaded_date.keys():  # check the channel is in the pickle file
            if last_downloaded_date[channel_id] is not None:  # check the last downloaded_date field
                return True
            else:
                return False
        else:
            return False

    else:
        return False


def create_list_of_dates_to_download(channel_id, level_qc, from_date, thru_date):
    """ generate a list of monthly start dates and end dates to download FAIMMS and NRS data """

    from dateutil import rrule
    from datetime import datetime
    from dateutil.relativedelta import relativedelta

    last_downloaded_date = get_last_downloaded_date_channel(channel_id, level_qc, from_date)
    start_dates          = []
    end_dates            = []

    from_date            = datetime.strptime(from_date, "%Y-%m-%dT%H:%M:%SZ")
    thru_date            = datetime.strptime(thru_date, "%Y-%m-%dT%H:%M:%SZ")
    last_downloaded_date = datetime.strptime(last_downloaded_date, "%Y-%m-%dT%H:%M:%SZ")

    if last_downloaded_date < thru_date:
        for dt in rrule.rrule(rrule.MONTHLY, dtstart=datetime(last_downloaded_date.year, last_downloaded_date.month, 1), until=thru_date):
            start_dates.append(dt)
            end_dates.append(datetime(dt.year, dt.month, 1) + relativedelta(months=1))

        end_dates[-1] = thru_date

    return start_dates, end_dates


def list_recursively_files_abs_path(path):
    """
    return a list containing the absolute path of files recursively found in a path
    :param path:
    :return:
    """
    filelist = []
    for filename in glob.glob('{path}/**'.format(path=path), recursive=True):
        if os.path.isfile(filename):
            filelist.append(os.path.abspath(filename))
    return filelist


def md5(fname):
    """ return a md5 checksum of a file """
    import hashlib

    hash = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash.update(chunk)
    return hash.hexdigest()


def get_main_netcdf_var(netcdf_file_path):
    with Dataset(netcdf_file_path, mode='r') as netcdf_file_obj:
        variables = netcdf_file_obj.variables

        variables.pop('TIME')
        variables.pop('LATITUDE')
        variables.pop('LONGITUDE')

        if 'NOMINAL_DEPTH' in variables:
            variables.pop('NOMINAL_DEPTH')

        qc_var = [s for s in variables if '_quality_control' in s]
        if qc_var != []:
            variables.pop(qc_var[0])

        return [item for item in variables.keys()][0]

    return variables[0]


def is_above_file_limit(json_watchd_name):
    """ check if the number of files in INCOMING DIR as set in watch.d/[JSON_WATCHD_NAME.json is above threshold
        SOMETHING quite annoying re the pipeline structure :
          * the watchd JSON filename maches the ERROR directory
          * BUT doesn't match the INCOMING_DIR. the 'path' in the watch.d json file matches the ERROR_DIR"""

    json_fp = os.path.join(os.environ['DATA_SERVICES_DIR'], 'watch.d', '%s.json' % json_watchd_name)
    with open(json_fp) as j_data:
        parsed_json = json.load(j_data)

        if len(os.listdir(os.path.join(os.environ['INCOMING_DIR'], parsed_json['path'][0]))) >= int(parsed_json['files_crit']):
            return True
        elif len(os.listdir(os.path.join(os.environ['ERROR_DIR'], json_watchd_name))) >= int(parsed_json['files_crit']):
            return True
        else:
            return False

######################
# XML Info Functions #
######################


@lru_cache(maxsize=100)
def parse_aims_xml(xml_url):
    """ Download and parse the AIMS XML rss feed """
    logger = logging.getLogger(__name__)
    logger.info('PARSE AIMS xml RSS feed : %s' % (xml_url))
    response        = urlopen(xml_url)
    html            = response.read()
    root            = ET.fromstring(html)

    n_item_start    = 3  # start number for AIMS xml file

    title           = []
    link            = []
    metadata_uuid   = []
    uom             = []
    from_date       = []
    thru_date       = []
    platform_name   = []
    site_name       = []
    channel_id      = []
    parameter       = []
    parameter_type  = []
    trip_id         = []  # soop trv only

    for n_item in range(n_item_start, len(root[0])):
        title         .append(root[0][n_item][0].text)
        link          .append(root[0][n_item][1].text)
        metadata_uuid .append(root[0][n_item][6].text)
        uom           .append(root[0][n_item][7].text)
        from_date     .append(root[0][n_item][8].text)
        thru_date     .append(root[0][n_item][9].text)
        platform_name .append(root[0][n_item][10].text)
        site_name     .append(root[0][n_item][11].text)
        channel_id    .append(root[0][n_item][12].text)
        parameter     .append(root[0][n_item][13].text)
        parameter_type.append(root[0][n_item][14].text)

        # in case there is no trip id defined by AIMS, we create a fake one, used by SOOP TRV only
        try:
            trip_id.append(root[0][n_item][15].text)
        except IndexError:
            dateObject   = time.strptime(root[0][n_item][8].text, "%Y-%m-%dT%H:%M:%SZ")
            trip_id_fake = str(dateObject.tm_year) + str(dateObject.tm_mon).zfill(2) + str(dateObject.tm_mday).zfill(2)
            trip_id.append(trip_id_fake)

    response.close()
    d = [{c: {'title': ttl,
              'channel_id': c,
              'link': lk,
              'metadata_uuid': muuid,
              'uom': uo,
              'from_date': fro,
              'thru_date': thr,
              'platform_name': pltname,
              'site_name': stname,
              'parameter': para,
              'parameter_type': paratype,
              'trip_id': trid
              }} for c, ttl, lk, muuid, uo, fro, thr, pltname, stname, para, paratype, trid in
         zip(channel_id, title, link, metadata_uuid, uom, from_date,
             thru_date, platform_name, site_name, parameter, parameter_type, trip_id)]

    # re-writting the dict to have the channel key as a key value
    new_dict = {}
    for item in d:
        for name in item.keys():
            new_dict[name] = item[name]

    return new_dict

##########################################
# Channel Process/Download/Mod Functions #
##########################################


def retry_if_result_none(result):
    """Return True if we should retry (in this case when result is None), False otherwise"""
    return result is None


@retry(retry_on_result=retry_if_result_none, stop_max_attempt_number=10, wait_fixed=2000)
def download_channel(channel_id, from_date, thru_date, level_qc):
    """ generated the data link to download, and extract the zip file into a temp file
    input:
        channel_id(str) : channel_id to download
        from_date(str)  : str containing the first time to start the download from written in this format 2009-04-21_t10:43:54Z
        thru_date(str)  : same as above but for the last date
        level_qc(int)   : 0 or 1
    """
    logger = logging.getLogger(__name__)
    tmp_zip_file      = tempfile.mkstemp()
    netcdf_tmp_path   = tempfile.mkdtemp()
    url_data_download = 'http://data.aims.gov.au/gbroosdata/services/data/rtds/%s/level%s/raw/raw/%s/%s/netcdf/2' % \
                        (channel_id, str(level_qc), from_date, thru_date)

    # set the timeout for no data to 120 seconds and enable streaming responses so we don't have to keep the file in memory
    headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36'}
    request = requests.get(url_data_download, timeout=120, stream=True, headers=headers)
    if request.status_code == 403:
        logger.error('Error 403: access to the requested resource is forbidden - {url}'.format(url=url_data_download))
        return

    with open(tmp_zip_file[1], 'wb') as fh:
        # Walk through the request response in chunks of 1024 * 1024 bytes, so 1MiB
        for chunk in request.iter_content(1024 * 1024):
            # Write the chunk to the file
            fh.write(chunk)

    if not zipfile.is_zipfile(tmp_zip_file[1]):
        logger.error('%s is not a valid zip file' % url_data_download)
        os.close(tmp_zip_file[0])
        os.remove(tmp_zip_file[1])  # file object needs to be closed or can end up with too many open files
        shutil.rmtree(netcdf_tmp_path)
        return

    zip = zipfile.ZipFile(tmp_zip_file[1])

    for name in zip.namelist():
        zip.extract(name, netcdf_tmp_path)
        netcdf_file_path = os.path.join(netcdf_tmp_path, name)

    zip.close()
    os.close(tmp_zip_file[0])
    os.remove(tmp_zip_file[1])  # file object needs to be closed or can end up with too many open files

    logger.info('%s download: SUCCESS' % url_data_download)
    return netcdf_file_path

####################################
# Functions to modify NetCDF files #
# AIMS NetCDF file specific only   #
####################################


def is_no_data_found(netcdf_file_path):
    """ Check if the unzipped file is a 'NO_DATA_FOUND' file instead of a netCDF file
    this behaviour is correct for FAIMMS and NRS, as it means no data for the selected
    time period. However it doesn't make sense for SOOP TRV
    """
    return os.path.basename(netcdf_file_path) == 'NO_DATA_FOUND'


def rename_netcdf_attribute(object_, old_attribute_name, new_attribute_name):
    """ Rename global attribute from netcdf4 dataset object
      object             = Dataset(netcdf_file, 'a', format='NETCDF4')
      old_attribute_name = current gatt name to modify
      new_attribute_name = new gatt name
    """
    setattr(object_, new_attribute_name, getattr(object_, old_attribute_name))
    delattr(object_, old_attribute_name)


def is_time_var_empty(netcdf_file_path):
    """ check if the yet unmodified file (time instead of TIME) has values in its time variable """
    netcdf_file_obj = Dataset(netcdf_file_path, 'r', format='NETCDF4')
    var_obj         = netcdf_file_obj.variables['time']

    if var_obj.shape[0] == 0:
        return True

    var_values = var_obj[:]
    netcdf_file_obj.close()

    return not var_values.any()


def convert_time_cf_to_imos(netcdf_file_path):
    """  convert a CF time into an IMOS one forced to be 'days since 1950-01-01 00:00:00'
    the variable HAS to be 'TIME'
    """
    try:
        netcdf_file_obj = Dataset(netcdf_file_path, 'a', format='NETCDF4')
        time            = netcdf_file_obj.variables['TIME']
        dtime           = num2date(time[:], time.units, time.calendar)  # this gives an array of datetime objects
        time.units      = 'days since 1950-01-01 00:00:00 UTC'
        time[:]         = date2num(dtime, time.units, time.calendar)  # conversion to IMOS recommended time
        netcdf_file_obj.close()
        return True
    except:
        logger = logging.getLogger(__name__)
        logger.error("TIME cannot be converted to IMOS format. debug required")
        return False


def strictly_increasing(list):
    """ check monotocity of list of values"""
    return all(x < y for x, y in zip(list, list[1:]))


def is_time_monotonic(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, 'r', format='NETCDF4')
    time            = netcdf_file_obj.variables['TIME'][:]
    netcdf_file_obj.close()
    if not strictly_increasing(time):
        return False
    return True


def modify_aims_netcdf(netcdf_file_path, channel_id_info):
    """ Modify the downloaded netCDF file so it passes both CF and IMOS checker
    input:
       netcdf_file_path(str)    : path of netcdf file to modify
       channel_id_index(dict) : information from xml for the channel
    """
    imos_env_path = os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib', 'netcdf', 'imos_env')
    if not os.path.isfile(imos_env_path):
        logger = logging.getLogger(__name__)
        logger.error('%s is not accessible' % imos_env_path)
        sys.exit(1)

    dotenv.load_dotenv(imos_env_path)
    netcdf_file_obj = Dataset(netcdf_file_path, 'a', format='NETCDF4')
    netcdf_file_obj.naming_authority = 'IMOS'

    # add gatts to NetCDF
    netcdf_file_obj.aims_channel_id = int(channel_id_info['channel_id'])

    if not (channel_id_info['metadata_uuid'] == 'Not Available'):
        netcdf_file_obj.metadata_uuid = channel_id_info['metadata_uuid']

    if not netcdf_file_obj.instrument_serial_number:
        del(netcdf_file_obj.instrument_serial_number)

    # add CF gatts, values stored in lib/netcdf/imos_env
    netcdf_file_obj.Conventions            = os.environ.get('CONVENTIONS')
    netcdf_file_obj.data_centre_email      = os.environ.get('DATA_CENTRE_EMAIL')
    netcdf_file_obj.data_centre            = os.environ.get('DATA_CENTRE')
    netcdf_file_obj.project                = os.environ.get('PROJECT')
    netcdf_file_obj.acknowledgement        = os.environ.get('ACKNOWLEDGEMENT')
    netcdf_file_obj.distribution_statement = os.environ.get('DISTRIBUTION_STATEMENT')

    netcdf_file_obj.date_created           = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime())
    netcdf_file_obj.quality_control_set    = 1
    imos_qc_convention                     = 'IMOS standard set using the IODE flags'
    netcdf_file_obj.author                 = 'laurent besnard'
    netcdf_file_obj.author_email           = 'laurent.besnard@utas.edu.au'

    rename_netcdf_attribute(netcdf_file_obj, 'geospatial_LAT_max', 'geospatial_lat_max')
    rename_netcdf_attribute(netcdf_file_obj, 'geospatial_LAT_min', 'geospatial_lat_min')
    rename_netcdf_attribute(netcdf_file_obj, 'geospatial_LON_max', 'geospatial_lon_max')
    rename_netcdf_attribute(netcdf_file_obj, 'geospatial_LON_min', 'geospatial_lon_min')

    # variables modifications
    time           = netcdf_file_obj.variables['time']
    time.calendar  = 'gregorian'
    time.axis      = 'T'
    time.valid_min = 0.0
    time.valid_max = 9999999999.0
    netcdf_file_obj.renameDimension('time', 'TIME')
    netcdf_file_obj.renameVariable('time', 'TIME')

    netcdf_file_obj.time_coverage_start = num2date(time[:], time.units, time.calendar).min().strftime('%Y-%m-%dT%H:%M:%SZ')
    netcdf_file_obj.time_coverage_end   = num2date(time[:], time.units, time.calendar).max().strftime('%Y-%m-%dT%H:%M:%SZ')

    # latitude longitude
    latitude                  = netcdf_file_obj.variables['LATITUDE']
    latitude.axis             = 'Y'
    latitude.valid_min        = -90.0
    latitude.valid_max        = 90.0
    latitude.reference_datum  = 'geographical coordinates, WGS84 projection'
    latitude.standard_name    = 'latitude'
    latitude.long_name        = 'latitude'

    longitude                 = netcdf_file_obj.variables['LONGITUDE']
    longitude.axis            = 'X'
    longitude.valid_min       = -180.0
    longitude.valid_max       = 180.0
    longitude.reference_datum = 'geographical coordinates, WGS84 projection'
    longitude.standard_name   = 'longitude'
    longitude.long_name       = 'longitude'

    # handle masked arrays
    lon_array = longitude[:]
    lat_array = latitude[:]
    if type(lon_array) != numpy.ma.core.MaskedArray or len(lon_array) == 1:
        netcdf_file_obj.geospatial_lon_min = min(lon_array)
        netcdf_file_obj.geospatial_lon_max = max(lon_array)
    else:
        netcdf_file_obj.geospatial_lon_min = numpy.ma.MaskedArray.min(lon_array)
        netcdf_file_obj.geospatial_lon_max = numpy.ma.MaskedArray.max(lon_array)

    if type(lat_array) != numpy.ma.core.MaskedArray or len(lat_array) == 1:
        netcdf_file_obj.geospatial_lat_min = min(lat_array)
        netcdf_file_obj.geospatial_lat_max = max(lat_array)
    else:
        numpy.ma.MaskedArray.min(lat_array)
        netcdf_file_obj.geospatial_lat_min = numpy.ma.MaskedArray.min(lat_array)
        netcdf_file_obj.geospatial_lat_max = numpy.ma.MaskedArray.max(lat_array)

    # Change variable name, standard name, longname, untis ....
    if 'Seawater_Intake_Temperature' in netcdf_file_obj.variables.keys():
        var                     = netcdf_file_obj.variables['Seawater_Intake_Temperature']
        var.units               = 'Celsius'
        netcdf_file_obj.renameVariable('Seawater_Intake_Temperature', 'TEMP')
        netcdf_file_obj.renameVariable('Seawater_Intake_Temperature_quality_control', 'TEMP_quality_control')
        var.ancillary_variables = 'TEMP_quality_control'

    if 'PSAL' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables['PSAL'].units = '1e-3'

    if 'TURB' in netcdf_file_obj.variables.keys():
        var                                                             = netcdf_file_obj.variables['TURB']
        var.units                                                       = '1'
        var.standard_name                                               = 'sea_water_turbidity'
        netcdf_file_obj.variables['TURB_quality_control'].standard_name = 'sea_water_turbidity status_flag'

    if 'DOWN_PHOTOSYNTH_FLUX' in netcdf_file_obj.variables.keys():
        var       = netcdf_file_obj.variables['DOWN_PHOTOSYNTH_FLUX']
        var.units = 'W m-2'

    if 'PEAK_WAVE_DIR' in netcdf_file_obj.variables.keys():
        var       = netcdf_file_obj.variables['PEAK_WAVE_DIR']
        var.units = 'degree'

    if 'CDIR' in netcdf_file_obj.variables.keys():
        var           = netcdf_file_obj.variables['CDIR']
        var.units     = 'degree'
        var.long_name = 'current_direction'

    if 'CSPD' in netcdf_file_obj.variables.keys():
        var           = netcdf_file_obj.variables['CSPD']
        var.long_name = 'current_magnitude'

    if 'ALBD' in netcdf_file_obj.variables.keys():
        var       = netcdf_file_obj.variables['ALBD']
        var.units = '1'

    def clean_no_cf_variables(var, netcdf_file_obj):
        """
        remove standard name of main variable and of its ancillary qc var if exists
        """
        if var in netcdf_file_obj.variables.keys():
            if hasattr(netcdf_file_obj.variables[var], 'standard_name'):
                del(netcdf_file_obj.variables[var].standard_name)
        var_qc = '%s_quality_control' % var
        if var_qc in netcdf_file_obj.variables.keys():
            if hasattr(netcdf_file_obj.variables[var_qc], 'standard_name'):
                del(netcdf_file_obj.variables[var_qc].standard_name)
            if hasattr(netcdf_file_obj.variables[var], 'ancillary_variables'):
                netcdf_file_obj.variables[var].ancillary_variables = var_qc

    if 'Dissolved_Oxygen_Percent' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('Dissolved_Oxygen_Percent', netcdf_file_obj)

    if 'ErrorVelocity' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('ErrorVelocity', netcdf_file_obj)
        netcdf_file_obj.variables['ErrorVelocity'].long_name = 'error_velocity'

    if 'Average_Compass_Heading' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('Average_Compass_Heading', netcdf_file_obj)
        var       = netcdf_file_obj.variables['Average_Compass_Heading']
        var.units = 'degree'

    if 'Upwelling_longwave_radiation' in netcdf_file_obj.variables.keys():
        var_str              = 'Upwelling_longwave_radiation'
        var_qc_str           = '%s_quality_control' % var_str
        var                  = netcdf_file_obj.variables[var_str]
        var_qc               = netcdf_file_obj.variables[var_qc_str]
        var.units            = 'W m-2'
        var.standard_name    = 'upwelling_longwave_flux_in_air'
        var_qc.standard_name = 'upwelling_longwave_flux_in_air status_flag'

    if 'Downwelling_longwave_radiation' in netcdf_file_obj.variables.keys():
        var_str              = 'Downwelling_longwave_radiation'
        var_qc_str           = '%s_quality_control' % var_str
        var                  = netcdf_file_obj.variables[var_str]
        var_qc               = netcdf_file_obj.variables[var_qc_str]
        var.units            = 'W m-2'
        var.standard_name    = 'downwelling_longwave_flux_in_air'
        var_qc.standard_name = 'downwelling_longwave_flux_in_air status_flag'

    if 'UP_TOT_RADIATION' in netcdf_file_obj.variables.keys():
        var_str              = 'UP_TOT_RADIATION'
        var_qc_str           = '%s_quality_control' % var_str
        var                  = netcdf_file_obj.variables[var_str]
        var_qc               = netcdf_file_obj.variables[var_qc_str]
        var.units            = 'W m-2'
        var.standard_name    = 'upwelling_longwave_flux_in_air'
        var_qc.standard_name = 'upwelling_longwave_flux_in_air status_flag'

    if 'DOWN_TOT_RADIATION' in netcdf_file_obj.variables.keys():
        var_str              = 'DOWN_TOT_RADIATION'
        var_qc_str           = '%s_quality_control' % var_str
        var                  = netcdf_file_obj.variables[var_str]
        var_qc               = netcdf_file_obj.variables[var_qc_str]
        var.units            = 'W m-2'
        var.standard_name    = 'downwelling_longwave_flux_in_air'
        var_qc.standard_name = 'downwelling_longwave_flux_in_air status_flag'

    if 'RADIATION_DOWN_NET' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('RADIATION_DOWN_NET', netcdf_file_obj)

    if 'fluorescence' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.renameVariable('fluorescence', 'CPHL')
        netcdf_file_obj.variables['CPHL'].long_name = 'mass_concentration_of_inferred_chlorophyll_from_relative_fluorescence_units_in_sea_water_concentration_of_chlorophyll_in_sea_water'
        if 'fluorescence_quality_control' in netcdf_file_obj.variables.keys():
            netcdf_file_obj.renameVariable('fluorescence_quality_control', 'CPHL_quality_control')
            netcdf_file_obj.variables['CPHL_quality_control'].long_name = 'mass_concentration_of_inferred_chlorophyll_from_relative_fluorescence_units_in_sea_waterconcentration_of_chlorophyll_in_sea_water status_flag'
        clean_no_cf_variables('CPHL', netcdf_file_obj)

    if 'WDIR_10min' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables['WDIR_10min'].units = 'degree'

    if 'WDIR_30min' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables['WDIR_30min'].units = 'degree'

    if 'R_sigma_30min' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables['R_sigma_30min'].units = 'degree'
        clean_no_cf_variables('R_sigma_30min', netcdf_file_obj)

    if 'WDIR_sigma_10min' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables['WDIR_sigma_10min'].units = 'degree'
        clean_no_cf_variables('WDIR_sigma_10min', netcdf_file_obj)

    if 'WDIR_sigma_30min' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables['WDIR_sigma_30min'].units = 'degree'
        clean_no_cf_variables('WDIR_sigma_30min', netcdf_file_obj)

    if 'ATMP' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables['ATMP'].units = 'hPa'

    if 'RAIN_DURATION' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('RAIN_DURATION', netcdf_file_obj)

    if 'HAIL_DURATION' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('HAIL_DURATION', netcdf_file_obj)

    if 'HAIL_HIT' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('HAIL_HIT', netcdf_file_obj)
        netcdf_file_obj.variables['HAIL_HIT'].comment = netcdf_file_obj.variables['HAIL_HIT'].units
        netcdf_file_obj.variables['HAIL_HIT'].units = '1'

    if 'HAIL_INTENSITY_10min' in netcdf_file_obj.variables.keys():
        clean_no_cf_variables('HAIL_INTENSITY_10min', netcdf_file_obj)
        netcdf_file_obj.variables['HAIL_INTENSITY_10min'].comment = netcdf_file_obj.variables['HAIL_INTENSITY_10min'].units
        netcdf_file_obj.variables['HAIL_INTENSITY_10min'].units = '1'

    # add qc conventions to qc vars
    variables = netcdf_file_obj.variables.keys()
    qc_vars = [s for s in variables if '_quality_control' in s]
    if qc_vars != []:
        for var in qc_vars:
            netcdf_file_obj.variables[var].quality_control_conventions = imos_qc_convention

    # clean longnames, force lower case, remove space, remove double underscore
    for var in variables:
        if hasattr(netcdf_file_obj.variables[var], 'long_name'):
            netcdf_file_obj.variables[var].long_name = netcdf_file_obj.variables[var].long_name.replace('__', '_')
            netcdf_file_obj.variables[var].long_name = netcdf_file_obj.variables[var].long_name.replace(' _', '_')
            netcdf_file_obj.variables[var].long_name = netcdf_file_obj.variables[var].long_name.lower()

    netcdf_file_obj.close()


def fix_provider_code_from_filename(netcdf_file_path, imos_facility_code):
    new_filename = re.sub('AIMS_', ('%s_' % imos_facility_code), netcdf_file_path)
    shutil.move(netcdf_file_path, new_filename)
    return new_filename


def fix_data_code_from_filename(netcdf_file_path):
    """ Some filename are badly written.
    this function has to run after modifying the file to make it CF and IMOS compliant
    It physically renames the filename if needed
    """

    netcdf_file_obj = Dataset(netcdf_file_path, 'r', format='NETCDF4')
    if 'CDIR' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_CDIR_', '_V_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'CSPD' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_CSPD_', '_V_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'DOX1' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_Dissolved_O2_\(mole\)_', '_K_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'DEPTH' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_DEPTH_', '_Z_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'Dissolved_Oxygen_Percent' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_DO_%_', '_O_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'ErrorVelocity' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_ErrorVelocity_', '_V_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'Average_Compass_Heading' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_Average_Compass_Heading_', '_E_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'Upwelling_longwave_radiation' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_Upwelling_longwave_radiation_', '_F_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    if 'Downwelling_longwave_radiation' in netcdf_file_obj.variables.keys():
        new_filename = re.sub('_Downwelling_longwave_radiation_', '_F_', netcdf_file_path)
        netcdf_file_obj.close()
        shutil.move(netcdf_file_path, new_filename)
        return new_filename

    netcdf_file_obj.close()
    return netcdf_file_path


def has_var_only_fill_value(netcdf_file_path, var):
    """ some channels have only _Fillvalues in their main variable. This is not correct and need
    to be tested
    var is a string of the variable to test
    """
    netcdf_file_obj = Dataset(netcdf_file_path, 'r', format='NETCDF4')
    var_obj         = netcdf_file_obj.variables[var]
    var_values      = var_obj[:]
    netcdf_file_obj.close()

    # if no fill value in variable, no mask attribute
    if hasattr(var_values, 'mask'):
        return var_values.mask.all()
    else:
        return False


def remove_dimension_from_netcdf(netcdf_file_path):
    """ DIRTY, calling bash. need to write in Python, or part of the NetCDF4 module
    need to remove the 'single' dimension name from DEPTH or other dim. Unfortunately can't seem to find a way to do it easily with netCDF4 module
    """
    fd, tmp_file = tempfile.mkstemp()
    os.close(fd)

    subprocess.check_call(['ncwa', '-O', '-a', 'single', netcdf_file_path, tmp_file])
    subprocess.check_call(['ncatted', '-O', '-a', 'cell_methods,,d,,', tmp_file, tmp_file])
    shutil.move(tmp_file, netcdf_file_path)


def remove_end_date_from_filename(netcdf_filename):
    """ remove the _END-* part of the file, as we download monthly file. This helps
    to overwrite file with new data for the same month
    """
    return re.sub('_END-.*$', '.nc', netcdf_filename)


def rm_tmp_dir(data_wip_path):
    """ remove temporary directories older than 15 days from data_wip path"""
    for dir_path in os.listdir(data_wip_path):
        if dir_path.startswith('manifest_dir_tmp_'):
            file_date = datetime.datetime.strptime(dir_path.split('_')[-1], '%Y%m%d%H%M%S')
            if (datetime.datetime.now() - file_date).days > 15:
                logger = logging.getLogger(__name__)
                logger.info('DELETE old temporary folder {path}'.format(path=os.path.join(data_wip_path, dir_path)))
                shutil.rmtree(os.path.join(data_wip_path, dir_path))


def set_up():
    """
    set up wip facility directories
    """
    wip_path = os.environ.get('data_wip_path')

    # this is used for unit testing as data_wip_path env would not be set
    if wip_path is None:
        wip_path = tempfile.mkdtemp()

    if not wip_path:
        logger = logging.getLogger(__name__)
        logger.error('env data_wip_path not defined')
        exit(1)

    if not os.path.exists(wip_path):
        os.makedirs(wip_path)

    if not os.path.exists(os.path.join(wip_path, 'errors')):
        os.makedirs(os.path.join(wip_path, 'errors'))
