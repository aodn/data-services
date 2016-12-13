#!/usr/bin/env python
"""
Download files from ftp server using the lftp command available on most Linux
system

Attributes:
    lftp_access: dictionnary of ftp and lftp parameters (see below)
    output_dir : path where files will be downloaded (dir will be created if
    not exists)

lftp_access dictionnary definition :

lftp_access = {
    'ftp_address':     'smuc.st-and.ac.uk',                    => ftp address
    'ftp_subdir':      '/pub/test',                            => subdirectory from ftp
    'ftp_user':        'user',                                 => user, can be empty
    'ftp_password':    'pwd',                                  => password, can be empty
    'ftp_exclude_dir': ['test', 'log'],                        => directories to exclude from download, can be empty
    'lftp_options':    '--only-newer --exclude-glob *.dmp.gz'  => any lftp optional agrument, see `man lftp`, can be empty
    'output_dir':      '/tmp/test'                             => the output directory where file will be downloaded, can be empty
    }
LFTPSync = LFTPSync()
LFTPSync.lftp_sync(lftp_access)
LFTPSync.list_new_files_path(check_file_exist=True)   => check on the filesystem if the files exist. default value is True
LFTPSync.list_new_files_path()
list_new_files_path_previous_log(lftp_access, check_file_exist=True):

LFTPSync.close()     # at the end of a script
------------------------------------
author : Besnard, Laurent
email  : laurent.besnard@utas.edu.au
"""

import os
import re
import shutil
import tempfile
import time
import urllib


class LFTPSync:

    def __init__(self):
        self.lftp_addr        = []
        self.lftp_subdir      = []
        self.lftp_usr         = []
        self.lftp_pwd         = []
        self.lftp_exclude_dir = []
        self.lftp_opts        = []
        self.output_dir       = []
        self.lftp_log_path    = []

    def _initialise_var(self, lftp_access):
        self.lftp_addr        = lftp_access['ftp_address']
        self.lftp_subdir      = lftp_access['ftp_subdir']
        self.lftp_usr         = lftp_access['ftp_user']
        self.lftp_pwd         = lftp_access['ftp_password']
        self.lftp_exclude_dir = lftp_access['ftp_exclude_dir']
        self.lftp_opts        = lftp_access['lftp_options']
        self.output_dir       = lftp_access['output_dir']

        if self.output_dir is None:
            self.output_dir = tempfile.tempfile.mkdtemp()

        if not os.path.exists(self.output_dir):
                os.makedirs(self.output_dir)

        self.lftp_log_path = os.path.join(self.output_dir, 'lftp_mirror.log')

    def _clean_log_file(self):
        archive_log_path = os.path.join(self.output_dir, '.log')
        if not os.path.exists(archive_log_path):
            os.makedirs(archive_log_path)

        timestr = time.strftime("%Y%m%d-%H%M%S")
        # remove log file from previous run, add timestamp and put to .log
        if os.path.exists(self.lftp_log_path):
            shutil.move(self.lftp_log_path, os.path.join(archive_log_path,
                       'lftp_mirror.log.%s' % timestr))

    def _no_usr_no_pwd_cmd(self):
        cmd = "lftp -e \'mirror --parallel=10 \
                    --log=%s %s %s %s %s\' %s <<EOF" % \
                    (self.lftp_log_path,
                     self.exclude_dir_opts, self.lftp_opts, self.lftp_subdir,
                     self.output_dir, self.lftp_addr)
        return cmd

    def _usr_pwd_cmd(self):
        cmd = "lftp -u %s,%s -e \'mirror --parallel=10 \
                    --log=%s %s %s %s %s\' %s <<EOF" % \
                    (self.lftp_usr, self.lftp_pwd, self.lftp_log_path,
                     self.exclude_dir_opts, self.lftp_opts, self.lftp_subdir,
                     self.output_dir, self.lftp_addr)
        return cmd

    def lftp_sync(self, lftp_access):
        self._initialise_var(lftp_access)
        self._clean_log_file()

        if self.lftp_exclude_dir is not None:
            exclude_dir_opts = [ "--exclude %s/" % dir for dir
                                in self.lftp_exclude_dir]
            self.exclude_dir_opts = ' '.join(exclude_dir_opts)
        else:
            self.exclude_dir_opts = ''

        # change cmd in case no user and password was given
        if self.lftp_usr is '' or self.lftp_pwd is '':
            cmd = self._no_usr_no_pwd_cmd()
        else:
            cmd = self._usr_pwd_cmd()

        try:
            os.system(cmd)
        except Exception, e:
            print str(e)

    def _list_new_files_from_log(self, check_file_exist):
        if not os.path.isfile(self.lftp_log_path):
            return []

        lines          = [line.rstrip('\n') for line in
                          open(self.lftp_log_path)]
        list_new_files = []
        for line in lines:
            line = urllib.unquote(line).decode('utf8')
            m = re.search('^get -O %s(.*) ftp://(.*)%s/(.*)$' %
              (self.output_dir, self.lftp_subdir), line)
            if m:
                new_file_path = os.path.join(self.output_dir, m.group(3))
                if check_file_exist:
                    if os.path.isfile(new_file_path):
                        # append only if file exist on filesystem
                        list_new_files.append(new_file_path)
                else:
                    list_new_files.append(new_file_path)
        return list_new_files

    def list_new_files_path(self, check_file_exist=True):
        """
        Open the lftp log file and generate a list of the fullpath of new
        downloaded files
        """
        return self._list_new_files_from_log(check_file_exist)

    def list_new_files_path_previous_log(self, lftp_access, check_file_exist=True):
        """
        same as list_new_files_path but for a already generated log file
        """
        self._initialise_var(lftp_access)
        return self._list_new_files_from_log(check_file_exist)

    def close(self):
        self._clean_log_file()
