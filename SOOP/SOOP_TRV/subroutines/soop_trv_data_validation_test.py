#!/usr/bin/env python
import unittest as data_validation_test
import os, sys
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from aims.realtime_util import *
from soop_trv import *

class AimsDataValidationTest(data_validation_test.TestCase):

    def setUp(self):
        """ Check that a the AIMS system or this script hasn't been modified.
        This function checks that a downloaded file still has the same md5.
        """
        logger                    = logging_aims()
        channel_id                = '8365'
        from_date                 = '2008-09-30T00:27:27Z'
        thru_date                 = '2008-09-30T00:30:00Z'
        level_qc                  = 1
        aims_rss_val              = 100
        xml_url                   = 'http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level%s/%s' % (str(level_qc), str(aims_rss_val))

        aims_xml_info             = parse_aims_xml(xml_url)
        channel_id_info           = get_channel_info(channel_id, aims_xml_info)
        self.netcdf_tmp_file_path = download_channel(channel_id, from_date, thru_date, level_qc)
        modify_soop_trv_netcdf(self.netcdf_tmp_file_path, channel_id_info)

        # force values of attributes which change all the time
        netcdf_file_obj              = Dataset(self.netcdf_tmp_file_path, 'a', format='NETCDF4')
        netcdf_file_obj.date_created = "1970-01-01T00:00:00Z"
        netcdf_file_obj.history      = 'data validation test only'
        netcdf_file_obj.close()

        shutil.move(self.netcdf_tmp_file_path, remove_creation_date_from_filename(self.netcdf_tmp_file_path))
        self.netcdf_tmp_file_path = remove_creation_date_from_filename(self.netcdf_tmp_file_path)

    def tearDown(self):
        shutil.rmtree(os.path.dirname(self.netcdf_tmp_file_path))

    def test_aims_validation(self):
        md5_expected_value = 'c15254c56151604e6b08f6a05521656c'
        md5_netcdf_value   = md5(self.netcdf_tmp_file_path)

        self.assertEqual(md5_netcdf_value, md5_expected_value)

if __name__ == '__main__':
   data_validation_test.main()
