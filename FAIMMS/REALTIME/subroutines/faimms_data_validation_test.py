#!/usr/bin/env python
import unittest as data_validation_test
import os, sys
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from aims.realtime_util import *
from faimms import *

class AimsDataValidationTest(data_validation_test.TestCase):

    def setUp(self):
        """ Check that a the AIMS system or this script hasn't been modified.
        This function checks that a downloaded file still has the same md5.
        """
        logger                       = logging_aims()
        channel_id                   = '9272'
        from_date                    = '2016-01-01T00:00:00Z'
        thru_date                    = '2016-01-02T00:00:00Z'
        level_qc                     = 1
        faimms_rss_val               = 1
        xml_url                      = 'http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level%s/%s' %(str(level_qc), str(faimms_rss_val))

        aims_xml_info                = parse_aims_xml(xml_url)
        channel_id_info              = get_channel_info(channel_id, aims_xml_info)
        self.netcdf_tmp_file_path    = download_channel(channel_id, from_date, thru_date, level_qc)
        modify_faimms_netcdf(self.netcdf_tmp_file_path, channel_id_info)

        # force values of attributes which change all the time
        netcdf_file_obj              = Dataset(self.netcdf_tmp_file_path, 'a', format='NETCDF4')
        netcdf_file_obj.date_created = "1970-01-01T00:00:00Z" #epoch
        netcdf_file_obj.history      = 'data validation test only'
        netcdf_file_obj.close()

    def tearDown(self):
        shutil.rmtree(os.path.dirname(self.netcdf_tmp_file_path))

    def test_aims_validation(self):
        md5_expected_value = '69947641a76e4a64f29d21b35358bd14'
        md5_netcdf_value   = md5(self.netcdf_tmp_file_path)

        self.assertEqual(md5_netcdf_value, md5_expected_value)

if __name__ == '__main__':
    data_validation_test.main()
