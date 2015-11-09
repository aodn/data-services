#!/usr/bin/python

import logging
import os
import subprocess
import util
import log

################
# S3 FUNCTIONS #
################

def _s3cmd():
    return os.environ['S3CMD']

def _s3cfg():
    return "TODO"

def delete(object_name, index=True):
    """
    Delete a file from s3 bucket (and call indexing)

    @type object_name: string
    @param object_name: Relative path to object to delete

    @type index: bool
    @param index: Whether to index or not the newly uploaded object

    @rtype: bool
    @return: True if operation succeeded, calls file_error otherwise
    """

    if index:
        if not unindex_file(object_name):
            return False

    log.log_info("Deleting '%s'" % object_name)

    dst = os.path.join(os.environ['S3_BUCKET'], object_name)
    command = [ s3cmd(), "--no-preserve", "--config=%s" % _s3cfg(), "del", dst ]

    try:
        output = subprocess.check_output(command, stderr=subprocess.STDOUT)
        log.log_info(output)
    except subprocess.CalledProcessError as e:
        log.log_error("Could not delete '%s'" % dst)
        log.log_error(e)
        return False

    return True

def put(src, object_name, index=True, keep_file=False, never_fail=False):
    """
    Put a file from s3 bucket (and call indexing)

    @type src: string
    @param src: Source file on disk

    @type object_name: string
    @param object_name: Relative path of object in bucket

    @type index: bool
    @param index: Whether to index or not the newly uploaded object

    @type keep_file: bool
    @param keep_file: Keep or not the file after uploading

    @type never_fail: bool
    @param never_fail: If set to True, do not call file_error on error

    @rtype: bool
    @return: True if operation succeeded, calls file_error otherwise
    """

    if index and not util.index_file(src, object_name):
        util.file_error("Could not be indexed as '%s'" % object_name)

    dst = os.path.join(os.environ['S3_BUCKET'], object_name)
    log.log_info("Moving '%s' -> '%s'" % (src, dst))

    if not util.set_permissions(src):
        util.file_error("Could not set permissions on '%s'" % src)

    command = [ _s3cmd(), "--no-preserve", "--config=%s" % _s3cfg(), "sync", src, dst ]
    try:
        output = subprocess.check_output(command, stderr=subprocess.STDOUT)
        log.log_info(output)
    except subprocess.CalledProcessError as e:
        log.log_error(e)
        if never_fail:
            None # Do nothing
        else:
            util.file_error("Could not push to S3 '%s' -> '%s'" % (src, dst))

    #if not subprocess.check_output(command) and not never_fail:
    #    #util.file_error("Could not push to S3 '%s' -> '%s'" % (src, dst))

    if not keep_file:
        os.remove(src)

    return True
