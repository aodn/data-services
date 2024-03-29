#!/usr/bin/env python3
# -*- coding: utf-8 -*-
""" Download SOOP TRV data from AIMS Web Service
The script reads an XML file provided by AIMS. The script then looks at which
new channel is available to download, and compare this list with a pickle file
(a python way to store python variables) containing what has already been
downloaded. Some modifications on the files have to be done in order to be CF
and IMOS compliant The files are stored in data_wip_path as defined by confix.txt

author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import errno
import logging
import os
import shutil
import sys
import traceback
import unittest as data_validation_test
from datetime import datetime

from dest_path import get_main_soop_trv_var, remove_creation_date_from_filename
from netCDF4 import Dataset
from tendo import singleton

from aims_realtime_util import (convert_time_cf_to_imos,
                                download_channel,
                                has_channel_already_been_downloaded,
                                get_last_downloaded_date_channel,
                                has_var_only_fill_value, is_no_data_found,
                                is_time_monotonic, logging_aims, md5,
                                modify_aims_netcdf, parse_aims_xml,
                                remove_dimension_from_netcdf, save_channel_info,
                                set_up)
from ship_callsign import ship_callsign
from util import pass_netcdf_checker


def modify_soop_trv_netcdf(netcdf_file_path, channel_id_info):
    """
    Modify the downloaded NetCDF file so it passes both CF and IMOS checker
    input:
    netcdfFile_path(str)    : path of netcdf file to modify
    channel_id_index(tupple) : information from xml for the channel
    """

    modify_aims_netcdf(netcdf_file_path, channel_id_info)
    netcdf_file_obj = Dataset(netcdf_file_path, 'a', format='NETCDF4')
    ship_code       = netcdf_file_obj.platform_code
    vessel_name     = ship_callsign(ship_code)

    if vessel_name is None:
        logger.error('   UNKNOWN SHIP - channel %s' % str(channel_id_info['channel_id']))
        netcdf_file_obj.close()
        return False

    # add gatts to net_cDF
    netcdf_file_obj.cdm_data_type = 'Trajectory'
    netcdf_file_obj.vessel_name   = vessel_name
    netcdf_file_obj.trip_id       = channel_id_info['trip_id']
    netcdf_file_obj.cdm_data_type = "Trajectory"
    coordinates_att               = "TIME LATITUDE LONGITUDE DEPTH"

    # depth
    depth                 = netcdf_file_obj.variables['depth']
    depth.positive        = 'down'
    depth.axis            = 'Z'
    depth.reference_datum = 'sea surface'
    depth.valid_max       = 30.0
    depth.valid_min       = -10.0
    netcdf_file_obj.renameVariable('depth', 'DEPTH')

    # latitude longitude
    latitude                      = netcdf_file_obj.variables['LATITUDE']
    latitude.ancillary_variables  = 'LATITUDE_quality_control'

    longitude                     = netcdf_file_obj.variables['LONGITUDE']
    longitude.ancillary_variables = 'LONGITUDE_quality_control'

    latitude_qc                   = netcdf_file_obj.variables['LATITUDE_quality_control']
    latitude_qc.long_name         = 'LATITUDE quality control'
    latitude_qc.standard_name     = 'latitude status_flag'
    longitude_qc                  = netcdf_file_obj.variables['LONGITUDE_quality_control']
    longitude_qc.long_name        = 'LONGITUDE quality control'
    longitude_qc.standard_name    = 'longitude status_flag'

    netcdf_file_obj.close()

    netcdf_file_obj = Dataset(netcdf_file_path, 'a', format='NETCDF4')
    main_var        = get_main_soop_trv_var(netcdf_file_path)
    netcdf_file_obj.variables[main_var].coordinates = coordinates_att

    netcdf_file_obj.close()

    if not convert_time_cf_to_imos(netcdf_file_path):
        return False

    remove_dimension_from_netcdf(netcdf_file_path)  # last modification to do !

    return True


def _is_lat_lon_values_outside_boundaries(netcdf_file_path):
    """ Some files had in the past bad latitude/longitude tracks. This is a
    really easy way to check this
    netcdf_file_path9str) : path of the netcdf file to check"""
    netcdf_file_obj = Dataset(netcdf_file_path, 'a', format='NETCDF4')
    lat             = netcdf_file_obj.variables['LATITUDE'][:]
    lon             = netcdf_file_obj.variables['LONGITUDE'][:]
    netcdf_file_obj.close()

    return any(lat > 0) or any(lat < -50) or any(lon > 180) or any(lon < 0)


def move_to_incoming(netcdf_path):
    incoming_dir      = os.environ.get('INCOMING_DIR')
    soop_incoming_dir = os.path.join(incoming_dir, 'SOOP/TRV',
                                     os.path.basename(netcdf_path))

    os.chmod(netcdf_path, 0o664)  # change to 664 for pipeline v2
    shutil.copy(netcdf_path, soop_incoming_dir)  # WARNING, shutil.move creates a wrong incron event
    os.remove(netcdf_path)


def process_channel(channel_id, aims_xml_info, level_qc):
    """ Downloads all the data available for one channel_id and moves the file to a wip_path dir
    channel_id(str)
    aims_xml_info(dict)
    level_qc(int)"""
    channel_id_info = aims_xml_info[channel_id]
    from_date = channel_id_info['from_date']
    thru_date = channel_id_info['thru_date']

    thru_date_already_downloaded = get_last_downloaded_date_channel(channel_id, level_qc, from_date)

    if not has_channel_already_been_downloaded(channel_id, level_qc) or \
            datetime.strptime(thru_date, "%Y-%m-%dT%H:%M:%SZ") > \
            datetime.strptime(thru_date_already_downloaded, "%Y-%m-%dT%H:%M:%SZ"):

        logger.info('QC{level_qc} - Processing channel {channel_id}'.format(channel_id=str(channel_id),
                                                                            level_qc=str(level_qc)))

        if datetime.strptime(thru_date, "%Y-%m-%dT%H:%M:%SZ") > \
                datetime.strptime(thru_date_already_downloaded, "%Y-%m-%dT%H:%M:%SZ"):
            logger.info('QC%s - Channel %s: Latest date downloaded: [%s]'
                        ' - New date available: [%s]' % (str(level_qc),
                                                         str(channel_id),
                                                         thru_date_already_downloaded,
                                                         thru_date))

        netcdf_tmp_file_path = download_channel(channel_id, from_date,
                                                thru_date, level_qc)

        contact_aims_msg = "Process of channel aborted - CONTACT AIMS"

        if not netcdf_tmp_file_path:
            logger.error('Channel {channel_id}: not valid zip file - {message}'.format(channel_id=str(channel_id),
                                                                                       message=contact_aims_msg))
            return False

        try:
            if is_no_data_found(netcdf_tmp_file_path):
                logger.error('Channel {channel_id}: NO_DATA_FOUND file in Zip file -{message}'.format(
                    channel_id=str(channel_id),
                    message=contact_aims_msg))
                return False

            if not modify_soop_trv_netcdf(netcdf_tmp_file_path, channel_id_info):
                logger.error('Channel {channel_id}:Could not modify the NetCDF file - \
                             {message}'.format(channel_id=str(channel_id),
                                               message=contact_aims_msg))
                return False

            main_var = get_main_soop_trv_var(netcdf_tmp_file_path)
            if has_var_only_fill_value(netcdf_tmp_file_path, main_var):
                logger.error('Channel {channel_id}: _Fillvalues only in main variable - \
                             {message}'.format(channel_id=str(channel_id),
                                               message=contact_aims_msg))
                return False

            if _is_lat_lon_values_outside_boundaries(netcdf_tmp_file_path):
                logger.error('Channel {channel_id}: Lat/Lon values outside of boundaries \
                             - {message}'.format(channel_id=str(channel_id),
                                                 message=contact_aims_msg))
                return False

            if not is_time_monotonic(netcdf_tmp_file_path):
                logger.error('Channel {channel_id}: TIME value is not strickly monotonic \
                             - {message}'.format(channel_id=str(channel_id),
                                                 message=contact_aims_msg))
                return False

            checker_retval = pass_netcdf_checker(netcdf_tmp_file_path, tests=['cf:1.6', 'imos:1.3'])
            if not checker_retval:
                wip_path = os.environ.get('data_wip_path')
                logger.error('Channel {channel_id}: File does not pass CF/IMOS \
                             compliance checker - {message}'.format(channel_id=str(channel_id),
                                                                    message=contact_aims_msg))
                shutil.copy(netcdf_tmp_file_path, os.path.join(wip_path, 'errors'))
                logger.error('File copied to %s for debugging'
                             % (os.path.join(wip_path, 'errors',
                                             os.path.basename(netcdf_tmp_file_path)
                                             )))
                return False

            move_to_incoming(netcdf_tmp_file_path)
            return True
        finally:
            # ensure temporary file and it's parent directory are removed
            try:
                shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
            except OSError as e:
                if e.errno != errno.ENOENT:
                    raise

    else:
        logger.info('QC{level_qc} - Channel {channel_id}: already processed'.format(channel_id=str(channel_id),
                                                                                    level_qc=str(level_qc)))

        return False


def process_qc_level(level_qc):
    """ Downloads all channels for a QC level
    level_qc(int) : 0 or 1"""
    logger.info('Process SOOP-TRV download from AIMS web service - QC level {level_qc}'.format(level_qc=str(level_qc)))
    xml_url = 'http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level%s/100' % str(level_qc)
    try:
        aims_xml_info = parse_aims_xml(xml_url)
    except Exception as err:
        logger.error('RSS feed not available')
        exit(1)

    for channel_id in aims_xml_info.keys():
        try:
            is_channel_processed = process_channel(channel_id, aims_xml_info,
                                                   level_qc)
            if is_channel_processed:
                save_channel_info(channel_id, aims_xml_info, level_qc)
        except Exception as err:
            logger.error('QC%s - Channel %s:ailed, unknown reason - manual \
                         debug required' % (str(level_qc), str(channel_id)))

            logger.error(str(err))
            logger.error(traceback.print_exc())


class AimsDataValidationTest(data_validation_test.TestCase):

    def setUp(self):
        """ Check that a the AIMS system or this script hasn't been modified.
        This function checks that a downloaded file still has the same md5.
        """
        channel_id                   = '8365'
        from_date                    = '2008-09-30T00:27:27Z'
        thru_date                    = '2008-09-30T00:30:00Z'
        level_qc                     = 1
        aims_rss_val                 = 100
        xml_url                      = 'http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level%s/%s' % (str(level_qc), str(aims_rss_val))

        logger.info('Data validation unittests...')
        aims_xml_info                = parse_aims_xml(xml_url)
        channel_id_info = aims_xml_info[channel_id]
        self.netcdf_tmp_file_path    = download_channel(channel_id, from_date, thru_date, level_qc)
        modify_soop_trv_netcdf(self.netcdf_tmp_file_path, channel_id_info)

        # force values of attributes which change all the time
        netcdf_file_obj              = Dataset(self.netcdf_tmp_file_path, 'a', format='NETCDF4')
        netcdf_file_obj.date_created = "1970-01-01T00:00:00Z"
        netcdf_file_obj.history      = 'data validation test only'
        netcdf_file_obj.NCO          = 'NCO_VERSION'
        netcdf_file_obj.close()

        shutil.move(self.netcdf_tmp_file_path, remove_creation_date_from_filename(self.netcdf_tmp_file_path))
        self.netcdf_tmp_file_path    = remove_creation_date_from_filename(self.netcdf_tmp_file_path)

    def tearDown(self):
        shutil.copy(self.netcdf_tmp_file_path, os.path.join(os.environ['data_wip_path'], 'nc_unittest_%s.nc' % self.md5_netcdf_value))
        shutil.rmtree(os.path.dirname(self.netcdf_tmp_file_path))

    def test_aims_validation(self):
        if sys.version_info[0] < 3:
            self.md5_expected_value = '18770178cd71c228e8b59ccba3c7b8b5'
        else:
            self.md5_expected_value = '1a72a8f040ec08073be0d49548a87879'

        self.md5_netcdf_value = md5(self.netcdf_tmp_file_path)

        self.assertEqual(self.md5_netcdf_value, self.md5_expected_value)


if __name__ == '__main__':
    me = singleton.SingleInstance()

    os.environ['data_wip_path'] = os.path.join(os.environ.get('WIP_DIR'), 'SOOP', 'SOOP_TRV_RSS_Download_temporary')
    set_up()

    # initialise logging
    logging_aims()
    global logger
    logger = logging.getLogger(__name__)

    # data validation to make sure input files don't vary. Manual debug required if different
    res = data_validation_test.main(exit=False)
    if res.result.wasSuccessful():
        process_qc_level(1)  # no need to process level 0 for SOOP TRV
    else:
        logger.error('Data validation unittests failed. Manual check required to see differences of Input NetCDF files')
