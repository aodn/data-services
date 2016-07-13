#!/usr/bin/env python
"""
unittest for lib/python/util.py wfs function

author : besnard, laurent
"""

import unittest
from util import wfs_request_matching_file_pattern

class TestGenerateNetCDFAtt(unittest.TestCase):

    def setUp(self):
        self.layer         = 'anmn_all_map'
        self.pattern       = '%IMOS_ANMN-NRS%FV01%NRSKAI%1511%Aqualogger%'
        self.url_column    = 'url'
        self.geoserver_url = 'http://geoserver-systest.aodn.org.au/geoserver/wfs' # needs to be set up as systest for pobox

    def test_wfs_request_matching_file_pattern(self):
        res =  wfs_request_matching_file_pattern(self.layer, self.pattern, geoserver_url=self.geoserver_url, url_column=self.url_column, s3_bucket_url=True)[0]
        self.assertTrue('IMOS_ANMN-NRS' in res, 'WFS pattern failure')

if __name__ == '__main__':
        unittest.main()
