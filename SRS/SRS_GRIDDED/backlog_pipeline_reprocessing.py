#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Script to copy and reprocess n_files_limit(default is 20) GHRSST files
via pipeline in order not to overflow the celery queue with backlog items to
reprocess. New files being uploaded by the facility will still be processed
within a reasonable time frame of couple of minutes max

This script should be run in a tmux/screen/background as it will take a long
long time to run
roughly 770000 files (10 sec/file) = 3 months of reprocessing

default input file is list_ghrsst_files.tgz . But any text file can be parsed
* $WIP_DIR/SRS/backlog_files_not_compliant contains a list of files not
compliant, so not pushed back yet. They need to be modified and re-uploaded by
the facility
* $WIP_DIR/SRS/backlog_ghrsst_files_already_reprocessed_to_pipeline


the list_ghrsst_files.tgz was generated AFTER new files already made it through
the generic timestep harvester. This meens that once this script finishes to
run, the only backlog left will be files not passing the ghrsst/cf checker
"""

import argparse
import errno
import gzip
import os
import shutil

from util import pass_netcdf_checker


def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise


def list_files(fname):
    "read content of text file into list. handle tgz file (smaller for github)"
    if fname.endswith('.gz'):
        with gzip.open(fname, 'rb') as f:
            return f.readlines()

    else:
        with open(fname) as f:
            return f.readlines()


def copy_files_to_inc(list_files_all_fp, list_files_already_copied_fp, n_files_limit=20):
    "copy files to incoming directory"
    list_files_all            = list_files(list_files_all_fp)
    list_files_all_basename   = [os.path.basename(f) for f in list_files_all]
    list_files_already_copied = list_files(list_files_already_copied_fp)

    # comparing list of basenames, ie without dir
    list_files_to_copy = set(list_files_all_basename).difference(list_files_already_copied)
    list_files_to_copy = sorted(list_files_to_copy, key=str)[:n_files_limit]

    incoming_path    = os.path.join(os.environ['INCOMING_DIR'], 'SRS', 'SST')
    n_files_incoming = len([name for name in os.listdir(incoming_path)])

    if n_files_incoming <= n_files_limit:
        for f_base in list_files_to_copy:
            f_base = f_base.rstrip()
            f_full = [s for s in list_files_all if f_base in s][0].rstrip()

            # precautious check, should be useless, but still good to have ...
            if f_base in f_full:
                checker_res = pass_netcdf_checker(f_full.rstrip(), tests=['cf:latest', 'ghrsst:latest'])
                if checker_res:
                    shutil.copy(f_full, os.path.join(incoming_path, f_base))
                else:
                    with open(os.path.join(os.path.dirname(list_files_already_copied_fp), 'backlog_files_not_compliant'), "a") as f:
                        f.write("%s\n" % f_base)

                # appending files to log of files already processed. even if a file
                # ended up not passing the checker, so it doesn't get reprocessed in
                # never ending loop
                with open(list_files_already_copied_fp, "a") as already_processed_log:
                    already_processed_log.write("%s\n" % f_base)


def check_backlog_status(list_files_all_fp, list_files_already_copied_fp):
    """check the status of files left to copy back to incoming dir.
    return true if the process needs to continue, false if everything got
    processed
    """
    list_files_all            = list_files(list_files_all_fp)
    list_files_all_basename   = [os.path.basename(f) for f in list_files_all]
    list_files_already_copied = list_files(list_files_already_copied_fp)

    list_files_to_copy = set(list_files_all_basename).difference(list_files_already_copied)

    if len(list_files_to_copy) == 0:
        return False
    else:
        return True


def args():
    """ define input argument"""
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--file-list-backlog', nargs='?', default=1,
                        help="path to a file containing backlog items to reprocess")
    vargs = parser.parse_args()

    if vargs.file_list_backlog == 1:
        vargs.file_list_backlog = os.path.join(os.path.dirname(__file__), 'list_ghrsst_files.gz')

    return vargs


if __name__ == "__main__":
    varg = args()
    list_files_all_fp = varg.file_list_backlog
    list_files_already_copied_fp = os.path.join(os.environ['WIP_DIR'], 'SRS', 'backlog_ghrsst_files_already_reprocessed_to_pipeline')

    # touch file
    if not os.path.exists(list_files_already_copied_fp):
        mkdir_p(os.path.dirname(list_files_already_copied_fp))
        open(list_files_already_copied_fp, 'w').close()

    while check_backlog_status(list_files_all_fp, list_files_already_copied_fp):
        copy_files_to_inc(list_files_all_fp, list_files_already_copied_fp)
