#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Download ANMN NRS data from AIMS Web Service for Darwin, Yongala and Beagle
The script reads an XML file provided by AIMS and looks for channels with
new data to download. It compares this list with a pickle file (pythonic
way to store python variables) containing what has already been downloaded
in the previous run of this script.
Some modifications on the files have to be done so they comply with CF and
IMOS conventions.
The IOOS compliance checker is used to check if the first downloaded file of
a channel complies once modified. If not, the download of the rest of the
channel is aborted until some modification on the source code is done so
the channel can pass the checker.
Files which don't pass the checker will land in os.path.join(wip_path, 'errors')
for investigation. No need to reprocess them as they will be redownloaded on
next run until they end up passing the checker. Files in the 'errors' dir can be
removed at anytime

IMPORTANT:
is it essential to look at the logging os.path.join(wip_path, 'aims.log')
to know which channels have problems and why as most of the time, AIMS will
have to be contacted to sort out issues.


author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import logging
import os
import re
import shutil
import sys
import time
import unittest as data_validation_test
from time import strftime

from netCDF4 import Dataset, date2num, num2date
from tendo import singleton

from aims.realtime_util import *
from dest_path import *

# generic aims functions to access aims web service
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))

def modify_anmn_nrs_netcdf(netcdf_file_path, channel_id_info):
    """ Modify the downloaded netCDF file so it passes both CF and IMOS checker
    input:
       netcdf_file_path(str)    : path of netcdf file to modify
       channel_id_index(tupple) : information from xml for the channel
    """
    modify_aims_netcdf(netcdf_file_path, channel_id_info)

    netcdf_file_obj                 = Dataset(netcdf_file_path, 'a', format='NETCDF4')
    netcdf_file_obj.aims_channel_id = int(channel_id_info[0])

    if 'Yongala' in channel_id_info[6]:
        netcdf_file_obj.site_code     = 'NRSYON'
        netcdf_file_obj.platform_code = 'Yongala NRS Buoy'
    elif 'Darwin' in channel_id_info[6]:
        netcdf_file_obj.site_code     = 'NRSDAR'
        netcdf_file_obj.platform_code = 'Darwin NRS Buoy'
    elif 'Beagle' in channel_id_info[6]:
        netcdf_file_obj.site_code     = 'DARBGF'
        netcdf_file_obj.platform_code = 'Beagle Gulf Mooring'
    else:
        return False

    if not (channel_id_info[3] == 'Not Available'):
        netcdf_file_obj.metadata_uuid = channel_id_info[3]

    # some weather stations channels don't have a depth variable if sensor above water
    if 'depth' in netcdf_file_obj.variables.keys():
        var                 = netcdf_file_obj.variables['depth']
        var.long_name       = 'nominal depth'
        var.positive        = 'down'
        var.axis            = 'Z'
        var.reference_datum = 'sea surface'
        var.valid_min       = -10.0
        var.valid_max       = 30.0
        var.units           = 'm' # some channels put degrees celcius instead ...
        netcdf_file_obj.renameVariable('depth', 'NOMINAL_DEPTH')

    if 'DEPTH' in netcdf_file_obj.variables.keys():
        var                 = netcdf_file_obj.variables['DEPTH']
        var.coordinates     = "TIME LATITUDE LONGITUDE NOMINAL_DEPTH"
        var.long_name       = 'actual depth'
        var.reference_datum = 'sea surface'
        var.positive        = 'down'
        var.valid_min       = -10.0
        var.valid_max       = 30.0
        var.units           = 'm' # some channels put degrees celcius instead ...

    netcdf_file_obj.close()
    netcdf_file_obj = Dataset(netcdf_file_path, 'a', format='NETCDF4') # need to close to save to file. as we call get_main_var just after
    main_var        = get_main_anmn_nrs_var(netcdf_file_path)
    # DEPTH, LATITUDE and LONGITUDE are not dimensions, so we make them into auxiliary cooordinate variables by adding this attribute
    if 'NOMINAL_DEPTH' in netcdf_file_obj.variables.keys():
        netcdf_file_obj.variables[main_var].coordinates = "TIME LATITUDE LONGITUDE NOMINAL_DEPTH"
    else:
        netcdf_file_obj.variables[main_var].coordinates = "TIME LATITUDE LONGITUDE"

    netcdf_file_obj.close()

    if not convert_time_cf_to_imos(netcdf_file_path):
        return False

    remove_dimension_from_netcdf(netcdf_file_path) # last modification to do in this order!
    return True

def move_to_incoming(netcdf_path):
    incoming_dir          = os.environ.get('INCOMING_DIR')
    anmn_nrs_incoming_dir = os.path.join(incoming_dir, 'ANMN', 'AIMS_NRS', '%s.%s' % (os.path.basename(remove_end_date_from_filename(netcdf_path)), md5(netcdf_path))) # add md5 to have unique file in incoming dir

    shutil.move(netcdf_path, anmn_nrs_incoming_dir)
    shutil.rmtree(os.path.dirname(netcdf_path))

def process_monthly_channel(channel_id, aims_xml_info, level_qc):
    """ Downloads all the data available for one channel_id and moves the file to a wip_path dir
    channel_id(str)
    aims_xml_info(tuple)
    level_qc(int)

    aims_service : 1   -> FAIMMS data
                   100 -> SOOP TRV data
                   300 -> NRS DATA
    for monthly data download, only 1 and 300 should be use
    """
    logger.info('>> QC%s - Processing channel %s' % (str(level_qc), str(channel_id)))
    channel_id_info          = get_channel_info(channel_id, aims_xml_info)
    from_date                = channel_id_info[1]
    thru_date                = channel_id_info[2]
    [start_dates, end_dates] = create_list_of_dates_to_download(channel_id, level_qc, from_date, thru_date)

    if len(start_dates) != 0 :
        # download monthly file
        for start_date, end_date in zip(start_dates, end_dates):
            start_date           = start_date.strftime("%Y-%m-%dT%H:%M:%SZ")
            end_date             = end_date.strftime("%Y-%m-%dT%H:%M:%SZ")
            netcdf_tmp_file_path = download_channel(channel_id, start_date, end_date, level_qc)
            contact_aims_msg     = "Process of channel aborted - CONTACT AIMS"

            if netcdf_tmp_file_path is None:
                logger.error('   Channel %s - not valid zip file - %s' % (str(channel_id), contact_aims_msg))
                break

            # NO_DATA_FOUND file only means there is no data for the selected time period. Could be some data afterwards
            if is_no_data_found(netcdf_tmp_file_path):
                logger.warning('   Channel %s - No data for the time period:%s - %s' % (str(channel_id), start_date, end_date))
                shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
            else:
                if is_time_var_empty(netcdf_tmp_file_path):
                    logger.error('   Channel %s - No values in TIME variable - %s' % (str(channel_id), contact_aims_msg))
                    shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
                    break

                if not modify_anmn_nrs_netcdf(netcdf_tmp_file_path, channel_id_info):
                    logger.error('   Channel %s - Could not modify the NetCDF file - Process of channel aborted' % str(channel_id))
                    shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
                    break

                main_var = get_main_anmn_nrs_var(netcdf_tmp_file_path)
                if has_var_only_fill_value(netcdf_tmp_file_path, main_var):
                    logger.error('   Channel %s - _Fillvalues only in main variable - %s' % (str(channel_id), contact_aims_msg))
                    shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
                    break

                if get_anmn_nrs_site_name(netcdf_tmp_file_path) == []:
                    logger.error('   Channel %s - Unknown site_code gatt value - %s' % (str(channel_id), contact_aims_msg))
                    shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
                    break

                if not is_time_monotonic(netcdf_tmp_file_path):
                    logger.error('   Channel %s - TIME value is not strickly monotonic - %s' % (str(channel_id), contact_aims_msg))
                    shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
                    break

                # check every single file of the list. We don't assume that if one passes, all pass ... past proved this
                wip_path = os.environ.get('data_wip_path')
                checker_retval = pass_netcdf_checker(netcdf_tmp_file_path, tests=['cf:latest', 'imos:1.3'])
                if not checker_retval:
                    logger.error('   Channel %s - File does not pass CF/IMOS compliance checker - Process of channel aborted' % str(channel_id))
                    shutil.copy(netcdf_tmp_file_path, os.path.join(wip_path, 'errors'))
                    logger.error('   File copied to %s for debugging' % (os.path.join(wip_path, 'errors', os.path.basename(netcdf_tmp_file_path))))
                    shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
                    break

                netcdf_tmp_file_path = fix_data_code_from_filename(netcdf_tmp_file_path)
                netcdf_tmp_file_path = fix_provider_code_from_filename(netcdf_tmp_file_path, 'IMOS_ANMN')

                if re.search('IMOS_ANMN_[A-Z]{1}_', netcdf_tmp_file_path) is None:
                    logger.error('   Channel %s - File name Data code does not pass REGEX - Process of channel aborted' % str(channel_id))
                    shutil.copy(netcdf_tmp_file_path, os.path.join(wip_path, 'errors'))
                    logger.error('   File copied to %s for debugging' % (os.path.join(wip_path, 'errors', os.path.basename(netcdf_tmp_file_path))))
                    shutil.rmtree(os.path.dirname(netcdf_tmp_file_path))
                    break

                move_to_incoming(netcdf_tmp_file_path)

                # The 2 next lines download the first month only for every single channel. This is only used for testing
                # save_channel_info(channel_id, aims_xml_info, level_qc, end_date)
                # break

            save_channel_info(channel_id, aims_xml_info, level_qc, end_date)

    else:
        logger.info('QC%s - Channel %s already up to date' % (str(level_qc), str(channel_id)))

    close_logger(logger)

def process_qc_level(level_qc):
    """ Downloads all channels for a QC level
    level_qc(int) : 0 or 1
    """

    logger.info('Process ANMN NRS download from AIMS web service - QC level %s' % str(level_qc))
    xml_url = 'http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level%s/300' % str(level_qc)
    try:
        aims_xml_info = parse_aims_xml(xml_url)
    except:
        logger.error('RSS feed not available')
        exit(1)

    for channel_id in aims_xml_info[0]:
        try:
            process_monthly_channel(channel_id , aims_xml_info, level_qc)
        except:
            logger.error('   Channel %s QC%s - Failed, unknown reason - manual debug required' % (str(channel_id), str(level_qc)))

class AimsDataValidationTest(data_validation_test.TestCase):

    def setUp(self):
        """ Check that a the AIMS system or this script hasn't been modified.
        This function checks that a downloaded file still has the same md5.
        """
        logger                       = logging_aims()
        channel_id                   = '84329'
        from_date                    = '2016-01-01T00:00:00Z'
        thru_date                    = '2016-01-02T00:00:00Z'
        level_qc                     = 1
        aims_rss_val                 = 300
        xml_url                      = 'http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level%s/%s' %(str(level_qc), str(aims_rss_val))

        aims_xml_info                = parse_aims_xml(xml_url)
        channel_id_info              = get_channel_info(channel_id, aims_xml_info)
        self.netcdf_tmp_file_path    = download_channel(channel_id, from_date, thru_date, level_qc)
        modify_anmn_nrs_netcdf(self.netcdf_tmp_file_path, channel_id_info)

        # force values of attributes which change all the time
        netcdf_file_obj              = Dataset(self.netcdf_tmp_file_path, 'a', format='NETCDF4')
        netcdf_file_obj.date_created = "1970-01-01T00:00:00Z" #epoch
        netcdf_file_obj.history      = 'data validation test only'
        netcdf_file_obj.close()

    def tearDown(self):
        shutil.copy(self.netcdf_tmp_file_path, os.path.join(os.environ['data_wip_path'], 'nc_unittest_%s.nc' % self.md5_netcdf_value))
        shutil.rmtree(os.path.dirname(self.netcdf_tmp_file_path))

    def test_aims_validation(self):
        self.md5_expected_value = '3f75d23eb5b4e2b0bbf5b35afc9cfa3f'
        self.md5_netcdf_value   = md5(self.netcdf_tmp_file_path)

        self.assertEqual(self.md5_netcdf_value, self.md5_expected_value)


if __name__ == '__main__':
    me  = singleton.SingleInstance()
    os.environ['data_wip_path'] = os.path.join(os.environ.get('WIP_DIR'), 'ANMN', 'NRS_AIMS_Darwin_Yongala_data_rss_download_temporary')
    set_up()
    res = data_validation_test.main(exit=False)

    logger = logging_aims()

    if res.result.wasSuccessful():
        process_qc_level(0)
        process_qc_level(1)
    else:
        logger.warning('Data validation unittests failed')

    close_logger(logger)
    exit(0)
