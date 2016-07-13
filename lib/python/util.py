#!/usr/bin/env python
"""
various utils which don't fit anywhere else
imports could be in functions for portability reasons
"""


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

def get_git_revision_script_url(file_path):
    """
    file_path is the local file path in a github repo
    returns the github url with the hash value of the current HEAD
    Only handles `git config --get remote.origin.url` output in the form defined
    in pattern variable
    """
    from git import Repo
    import os
    import re

    repo = Repo(file_path, search_parent_directories=True)
    hash_val = str(repo.commit('HEAD'))
    script_rel_path = os.path.relpath(file_path, repo.working_tree_dir)

    pattern = '(.*)@(.*):(.*)/(.*)$'
    regroup = re.search(pattern, repo.remotes.origin.url)
    try:
        user, host, organisation, repo_name = regroup.group(1, 2, 3, 4)
    except ValueError:
        # the default message is very vague, so rethrow with a more descriptive message
        raise ValueError('Cannot parse remote.origin.url')

    return '{0}/{1}/{2}/blob/{3}/{4}'.format(host, organisation, re.sub('\.git$', '', repo_name), hash_val, script_rel_path)

def wfs_request_matching_file_pattern(imos_layer_name, filename_wfs_filter, url_column='url', geoserver_url='http://geoserver-123.aodn.org.au/geoserver/wfs', s3_bucket_url=False):
    """
    returns a list of url matching a file pattern defined by filename_wfs_filter
    * if s3_bucket_url is False, returns the url as stored in WFS layer
    * if s3_bucket_url is True, append to its start the s3 IMOS bucket link used to
      download the file
    Examples:
    wfs_request_matching_file_pattern('srs_oc_ljco_wws_hourly_wqm_fv01_timeseries_map', '%')
    wfs_request_matching_file_pattern('srs_oc_ljco_wws_hourly_wqm_fv01_timeseries_map', '%', s3_bucket_url=True)
    wfs_request_matching_file_pattern('srs_oc_ljco_wws_hourly_wqm_fv01_timeseries_map', '%2014/06/%')
    wfs_request_matching_file_pattern('anmn_nrs_rt_meteo_timeseries_map', '%IMOS_ANMN-NRS_MT_%', url_column='file_url', s3_bucket_url=True)

    WARNING: Please exec $DATA_SERVICES_DIR/lib/test/python/manual_test_wfs_query.py to run unittests before modifying function
    """
    from owslib.etree import etree
    from owslib.fes import PropertyIsLike
    from owslib.wfs import WebFeatureService
    import os
    import xml.etree.ElementTree as ET

    imos_layer_name  = 'imos:%s' % imos_layer_name
    s3_bucket_prefix = 'http://data.aodn.org.au'

    wfs11     = WebFeatureService(url=geoserver_url, version='1.1.0')
    filter    = PropertyIsLike(propertyname=url_column, literal=filename_wfs_filter, wildCard='%')
    filterxml = etree.tostring(filter.toXML()).decode("utf-8")
    response  = wfs11.getfeature(typename=imos_layer_name, filter=filterxml)

    # parse XML to get list of URLS
    xml_wfs_output   = response.read()
    root             = ET.fromstring(xml_wfs_output)
    list_url         = []

    # parse xml
    if len(root) > 0 :
        for item in root[0]:
            for subitem in item:
                if url_column in subitem.tag:
                    nc_file = subitem.text
                    if s3_bucket_url:
                        list_url.append(os.path.join(s3_bucket_prefix, nc_file))
                    else:
                        list_url.append(nc_file)

    return list_url
