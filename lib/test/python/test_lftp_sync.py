#!/usr/bin/env python
"""
unittest for the lftp_sync class to find additions of new files
lib/python/lftp_mirror.py library

author : besnard, laurent
"""

import os
import sys

import unittest
import shutil
import textwrap
from tempfile import mkdtemp, mkstemp
from lftp_sync import LFTPSync

class TestGenerateNetCDFAtt(unittest.TestCase):

    def setUp(self):
        self.lftp = LFTPSync()
        self.output_dir = mkdtemp()
        self.lftp_access = {
                'ftp_address':     'smuc.st-and.ac.uk',
                'ftp_subdir':      '/pub/bodc',
                'ftp_user':        'user',
                'ftp_password':    'pwd',
                'ftp_exclude_dir': ['test', 'log'],
                'lftp_options':    '--only-newer --exclude-glob *.dmp.gz',
                'output_dir':      self.output_dir
                }

        self.setup_lftp_mirror_log()

    def setup_lftp_mirror_log(self):
        self.file1_lftp = [mkstemp(dir = self.output_dir)]
        self.file2_lftp = [mkstemp(dir = self.output_dir)]

        lftp_log = textwrap.dedent(
            """
            get -O %s ftp://:@smuc.st-and.ac.uk/pub/bodc/%s
            get -O %s ftp://:@smuc.st-and.ac.uk/pub/bodc/%s
            """ % (self.output_dir, os.path.basename(self.file1_lftp[0][1]),
                   self.output_dir, os.path.basename(self.file2_lftp[0][1])))

        self.log_file = os.path.join(self.output_dir, 'lftp_mirror.log')
        with open(self.log_file, 'w') as f:
            f.write(lftp_log)

    def tearDown(self):
        os.close(self.file1_lftp[0][0])
        os.close(self.file2_lftp[0][0])
        shutil.rmtree(self.output_dir)

    def test_list_new_files_path_previous_log(self):
        res = self.lftp.list_new_files_path_previous_log(self.lftp_access,
                                                        check_file_exist=True)

        # check the 2 files were seen by the log function
        self.assertEqual(res[0], self.file1_lftp[0][1])
        self.assertEqual(res[1], self.file2_lftp[0][1])


if __name__ == '__main__':
        unittest.main()
