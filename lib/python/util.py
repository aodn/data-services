#!/usr/bin/env python3.5
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

    url = '{0}/{1}/{2}/blob/{3}/{4}'.format(host,
                                            organisation,
                                            re.sub('\.git$', '', repo_name),
                                            hash_val,
                                            script_rel_path)

    if url.startswith('http://') or url.startswith('https://'):
        return url
    else:
        return 'https://{url}'.format(url=url)



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
    data_aodn_http_prefix = 'http://data.aodn.org.au'

    wfs11     = WebFeatureService(url=geoserver_url, version='1.1.0')
    wfs_filter= PropertyIsLike(propertyname=url_column, literal=filename_wfs_filter, wildCard='%')
    filterxml = etree.tostring(wfs_filter.toXML()).decode("utf-8")
    response  = wfs11.getfeature(typename=imos_layer_name, filter=filterxml, propertyname=[url_column])

    # parse XML to get list of URLS
    xml_wfs_output   = response.read()
    root             = ET.fromstring(xml_wfs_output)
    list_url         = []

    # parse xml
    if len(root) > 0 :
        for item in root[0]:
            for subitem in item:
                file_url = subitem.text
                if s3_bucket_url:
                    list_url.append(os.path.join(data_aodn_http_prefix, file_url))
                else:
                    list_url.append(file_url)

    return list_url


def pass_netcdf_checker(netcdf_file_path, tests=['cf:latest', 'imos:latest']):
    """Calls the netcdf checker and run the IMOS and CF latests version tests
    by default.
    Returns True if passes, False otherwise
    """
    from compliance_checker.runner import ComplianceChecker, CheckSuite
    import tempfile
    import os

    tmp_json_checker_output = tempfile.mkstemp()
    return_values           = []
    had_errors              = []
    CheckSuite.load_all_available_checkers()

    for test in tests:
        # creation of a tmp json file. Only way (with html) to create an output not displayed to stdin by default
        return_value, errors = ComplianceChecker.run_checker(netcdf_file_path, [test], 1, 'normal', output_filename=tmp_json_checker_output[1], output_format='json')
        had_errors.append(errors)
        return_values.append(return_value)

    os.close(tmp_json_checker_output[0])
    os.remove(tmp_json_checker_output[1]) #file object needs to be closed or can end up with too many open files

    if any(had_errors):
        return False # checker exceptions
    if all(return_values):
        return True # all tests passed
    return False # at least one did not pass


def download_list_urls(list_url):
    """Downloads a list of URLs in a temporary directory.
    Returns the path to this temporary directory.
    """
    import tempfile
    import urllib2
    import os
    
    tmp_dir = tempfile.mkdtemp()

    for url in list_url:
        file_name = url.split('/')[-1]
        u = urllib2.urlopen(url)
        f = open(os.path.join(tmp_dir, file_name), 'wb')
        meta = u.info()
        file_size = int(meta.getheaders("Content-Length")[0])

        file_size_dl = 0
        block_sz = 65536
        while True:
            buffer = u.read(block_sz)
            if not buffer:
                break

            file_size_dl += len(buffer)
            f.write(buffer)
            status = r"%10d  [%3.2f%%]" % (file_size_dl, file_size_dl * 100. / file_size)
            status = status + chr(8)*(len(status)+1)

        f.close()

    return tmp_dir


def get_s3_bucket_prefix():
    """Returns the S3 bucket prefix URL where IMOS data lives.
    """
    
    return 'https://s3-ap-southeast-2.amazonaws.com/imos-data'
