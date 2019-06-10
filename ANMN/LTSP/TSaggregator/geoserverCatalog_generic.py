## read all ANMN/ABOS files names form the geoserver
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
geoserverCatalog.py

Collect files names from the AODN geoserver according to several conditions
Output a list of urls and optionally write into a text file

"""


import sys
import argparse
from datetime import datetime, timedelta
from distutils.util import strtobool

import pandas as pd



def args():
    parser = argparse.ArgumentParser(description="Get a list of urls from the AODN geoserver")
    parser.add_argument('-var', dest='varname', help='name of the variable of interest, like TEMP', default=None, required=False)
    parser.add_argument('-site', dest='site', help='site code, like NRMMAI',  type=str, default=None, required=False)
    parser.add_argument('-ft', dest='featuretype', help='feature type, default timeseries', default=None, required=False)
    parser.add_argument('-fv', dest='fileversion', help='file version 1 or 2 only', default=None, type=int, required=False)
    parser.add_argument('-ts', dest='timestart', help='start time like 2015-12-01', default=None, type=str, required=False)
    parser.add_argument('-te', dest='timeend', help='end time like 2018-06-30', default=None, required=False)
    parser.add_argument('-out', dest='outFileList', help='name of the file to store the selected files urls. Default: filelist.csv', default=None, required=False)
    parser.add_argument('-realtime', help='only real time data files. If absent only delayed-mode data files', action="store_true")

    vargs = parser.parse_args()
    return(vargs)


def get_urls(varname=None, site=None, featuretype=None, fileversion=None, realtime=None, timestart=None, timeend=None, outFileList=None):

    """
    get the urls from the geoserver moorings_all_map collection
    based on user defined filters
    """

    if realtime:
        url = "http://geoserver-123.aodn.org.au/geoserver/ows?typeName=moorings_all_map&SERVICE=WFS&REQUEST=GetFeature&VERSION=1.0.0&outputFormat=csv&CQL_FILTER=(realtime=TRUE)"
    else:
        url = "http://geoserver-123.aodn.org.au/geoserver/ows?typeName=moorings_all_map&SERVICE=WFS&REQUEST=GetFeature&VERSION=1.0.0&outputFormat=csv&CQL_FILTER=(realtime=FALSE)"

    df = pd.read_csv(url)
    criteria_all = df.url != None

    ## get possible values
    separator = ', '
    varnames_all = set(separator.join(list(df.variables)).split(', '))
    varnames_all = set(str(list(df.variables)).split(", "))
    site_all = list(df.site_code.str.upper().unique())
    featuretype_all = list(df.feature_type. str.lower().unique())
    fileversion_all = list(df.file_version.unique())

    if varname:
        if varname in varnames_all:
            criteria_all = criteria_all & df.variables.str.contains('.*\\b'+varname+'\\b.*', regex=True)
        else:
            sys.exit('ERROR: %s not in the variable list' % varname)

    if site:
        if site in site_all:
            criteria_all = criteria_all & df.site_code.str.contains(site, regex=False)
        else:
            sys.exit('ERROR: %s is not in the site_code list' % site)

    if featuretype:
        if featuretype in featuretype_all:
            criteria_all = criteria_all & df.feature_type == featuretype
        else:
            sys.exit('ERROR: %s is not in the feature_type list' % featuretype)

    if fileversion:
        if fileversion in fileversion_all:
            criteria_all = criteria_all & df.file_version == fileversion
        else:
            sys.exit('ERROR: %s is not in the fileversion list' % featuretype)

    if timestart:
        try:
            criteria_all = criteria_all & pd.to_datetime(df.time_coverage_end) >= datetime.strptime(timestart, '%Y-%m-%d')
        except ValueError:
            sys.exit('ERROR: invalid start date.')

    if timeend:
        try:
            criteria_all = criteria_all & pd.to_datetime(df.time_coverage_start) <=  datetime.strptime(timeend, '%Y-%m-%d')
        except ValueError:
            sys.exit('ERROR: invalid end date.')

    if outFileList:
        df.url[criteria_all].to_csv(outFileList, index=False)

    return(df.url[criteria_all])


if __name__ == "__main__":
    vargs = args()
    get_urls(**vars(vargs))
