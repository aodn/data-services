#!/usr/bin/env python
"""
various utils which don't fit anywhere else
imports could be in functions for portability reasons
"""

import os
import time
import subprocess
import logging
import tempfile
import subprocess
import zipfile
import log

def md5_file(file):
    """
    returns the md5 checksum of a file

    TODO : write unittest
    """
    import hashlib
    hash = hashlib.md5()
    with open(file, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash.update(chunk)
    return hash.hexdigest()


def list_files_recursively(dir, pattern):
    """
    Look recursievely for files in dir matching a certain pattern

    TODO : write unittest
    """
    import fnmatch
    import os

    matches = []
    for root, dirnames, filenames in os.walk(dir):
        for filename in fnmatch.filter(filenames, pattern):
            matches.append(os.path.join(root, filename))

    return matches

############################
# HELPER PRIVATE FUNCTIONS #
############################

def set_permissions(f):
    """
    Set standard permissions on target file (00444)

    @type f: string
    @param f: Full path to file

    @rtype: bool
    @return: True if successful, False otherwise
    """

    chmod_command = [ "sudo", "chmod", "00444", f ]
    chown_command = [ "sudo", "chown", "%s%s" % (os.getuid(), os.getgid()), f ]

    try:
        subprocess.check_output(chmod_command)
        subprocess.check_output(chown_command)
    except CalledProcessError as e:
        log.log_error("Error setting permissions on '%s'" % f)
        log.log_error(e)
        return False

    return True

def bulk_index_impl(cdTo, base, fileList):
    """
    Bulk index/unindex files using talend

    @type cdTo: string
    @param cdTo: Directory to cd to before operation

    @type base: string
    @param base: Base to index files with (prefix, such as IMOS/Argo)

    @type fileList: string
    @param fileList: File containing list of files to index

    @rtype: bool
    @return: True if successful, False otherwise
    """

    harvesterTrigger = os.environ['HARVESTER_TRIGGER']
    if not 'HARVESTER_TRIGGER' in os.environ:
        log.log_info("Indexing disabled")
        return True

    tmp_harvester_output = tempfile.mktemp()

    retval = True

    # TODO
    #local tmp_harvester_output=`mktemp`
    #local log_file=`get_log_file $LOG_DIR $file_list`
    #(cd $cd_to && cat $file_list | $HARVESTER_TRIGGER --stdin -b $base "$@" >& $tmp_harvester_output)
    #local -i retval=$?
    # TODO redirect to log file
    if not subprocess.check_output(harvest_cmd):
        log.log_error("Bulk indexing failed for '%s', verbose log saved at '%s'" % (fileList, logFile))
        retval = False

    os.unlink(dst)
    return retval

def index_files_bulk(cdTo, base, fileList):
    """
    Bulk index files using talend

    @type cdTo: string
    @param cdTo: Directory to cd to before operation

    @type base: string
    @param base: Base to index files with (prefix, such as IMOS/Argo)

    @type fileList: string
    @param fileList: File containing list of files to index

    @rtype: bool
    @return: True if successful, False otherwise
    """
    return bulk_index_impl(cdTo, base, fileList)

def index_file_impl(src, object_name, delete=False):
    """
    Calls talend to index/unindex a single file

    @type src: string
    @param src: Source file to index/unindex

    @type object_name: string
    @param object_name: Object name to index as

    @type delete: bool
    @param object_name: Pass True to trigger a delete

    @rtype: bool
    @return: True if successful, False otherwise
    """

    if not 'HARVESTER_TRIGGER' in os.environ:
        log.log_info("Indexing disabled")
        return True

    tmp_harvester_output = tempfile.mktemp()

    delete_arg = ""
    if delete:
        delete_arg = "--delete"

    harvest_cmd = [
        '/usr/local/talend/bin/talend-trigger', '-c', '/usr/local/talend/etc/trigger.conf',
        #os.environ['HARVESTER_TRIGGER'],
        delete_arg,
        "-f",
        "%s,%s" % (src, object_name)
    ] # >& tmp_harvester_output
    # TODO redirect to log file

    log.log_info(harvest_cmd)
    log_file = log.get_log_file(os.environ['LOG_DIR'], src)

    try:
        output = subprocess.check_output(harvest_cmd, stderr=subprocess.STDOUT)
        log.log_to_file(log_file, output)
    except subprocess.CalledProcessError as e:
        log.log_error("Indexing failed for '%s', verbose log saved at '%s'" (object_name, logFile))
        log.log_error(e)
        return False

    return True

def index_file(src, object_name):
    """
    Calls talend to index a single file

    @type src: string
    @param src: Source file to index (must be a real file)

    @type object_name: string
    @param object_name: Object name to index as

    @rtype: bool
    @return: True if successful, False otherwise
    """

    return index_file_impl(src, object_name)

def unindex_file(object_name):
    """
    Calls talend to unindex a single file

    @type object_name: string
    @param object_name: Object name to index as

    @rtype: bool
    @return: True if successful, False otherwise
    """

    return index_file_impl(object_name, object_name, delete=True)

###########################
# FILE HANDLING FUNCTIONS #
###########################

def file_error_impl(f, msg):
    """
    Move file to error directory, then terminates program

    @type f: string
    @param f: File to move

    @type msg: string
    @param msg: Message to log

    @rtype: None
    @return: None
    """

    if not os.path.isfile(f):
        log.log_error("'%s' is not a valid file, aborting.")
        exit(1)

    log.log_error("Could not process file '%s': %s" % (f, msg))
    dstDir = os.path.join(os.environ['ERROR_DIR'], os.environ['JOB_NAME']) # TODO python vars
    dst = os.path.join(dstDir, "%s.%s" % (os.path.basename(f), os.environ['TRANSACTION_ID'])) # TODO python vars

    log.log_error("Moving '%s' -> '%s'" % (f, dst))

    # TODO ugly directory creation
    if not subprocess.check_output(['mkdir', '-p', dstDir]):
        log.log_error("Could not create directory '%s'" % dstDir)
        exit(1)

    if not mv_retry(f, dst):
        log.log_error("Could not move '%s' -> '%s'" % (f, dst))
        exit(1)

    exit(1)

def file_error(msg, recipient=None):
    """
    Move handled file to error directory

    @type msg: string
    @param msg: Message to log

    @rtype: None
    @return: None
    """

    if recipient is not None:
        send_report(os.environ['INCOMING_FILE'], recipient, msg)

    file_error_impl(os.environ['INCOMING_FILE'], msg) # TODO environ


"""
# uses file_error to handle a file error, but also report the error to the
# uploader
# $1 - file to report
# $2 - backup recipient, in case we cannot determine uploader
# "$@" - message to log and subject for report email
file_error_and_report_to_uploader() {
    local backup_recipient=$1; shift

    send_report_to_uploader $INCOMING_FILE $backup_recipient "$@"
    _file_error $INCOMING_FILE "$@"
}
export -f file_error_and_report_to_uploader

# returns relative path of file to given directory
# passing /mnt/1/test.nc /mnt results in 1/test.nc to be returned
# $1 - file
# $2 - directory
get_relative_path() {
    local file=$1; shift
    local path=$1; shift

    # empty $path? just return $file
    if [ -z $path ]; then
        echo $file; return
    fi

    # add trailing slash to given path
    if [[ "${path: -1}" != "/" ]]; then
        path="$path/"
    fi
    echo ${file##$path}
}
export -f get_relative_path

# returns relative path to incoming directory
# $1 - file
get_relative_path_incoming() {
    local file=$1; shift
    get_relative_path $file $INCOMING_DIR
}
export -f get_relative_path_incoming

# make a temporary, writable copy of a file, with the same basename
# print its full path
# $1 - file
make_writable_copy() {
    local file=$1; shift
    local file_basename=`basename $file`
    local tmp_file=`mktemp -t ${file_basename}.XXXXXX`
    cp $file $tmp_file && \
        chmod --reference=$file $tmp_file && \
        chmod u+w $tmp_file && \
        echo $tmp_file
}
export -f make_writable_copy
"""

def has_extension(f, ext):
    """
    Compares file extension

    @type f: string
    @param f: File

    @type ext: string
    @param ext: Extension to compare with

    @rtype: bool
    @return: True if file has given extension, false otherwise
    """

    if ext[0] != ".":
        ext = ".%s" % ext

    return os.path.splitext(f)[-1] == ext

def unzip_file(zip_file, dest_dir):
    """
    Extracts zip file

    @type zip_file: string
    @param zip_file: Zip file to extract

    @type dest_dir: string
    @param dest_dir: Directory to extract zip to

    @rtype: list
    @return: List with manifest of files
    """

    manifest = []
    zfile = zipfile.ZipFile(zip_file)
    for name in zfile.namelist():
        manifest.append(name)
        zfile.extract(name, dest_dir)

    return manifest
