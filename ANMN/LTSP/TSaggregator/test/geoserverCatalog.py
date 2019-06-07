## read all ANMN/ABOS files names form the geoserver
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
geoserverCatalog.py

Collect files names from the AODN geoserver according to several conditions
Output a list of urls and optionally write into a text file

usage: geoserverCatalog.py [-h] -var VAR -site SITE [-ft FEATURETYPE] [-fv FV]
                           [-realtime REALTIME] [-ts TIMESTART] [-te TIMEEND]
                           [-out OUTFILELIST]

optional arguments:
  -h, --help          show this help message and exit
  -var VAR            name of the variable of interest, like TEMP
  -site SITE          site code, like NRMMAI
  -ft FEATURETYPE     feature type, default timeseries
  -fv FV              file version, 0, 1 or 2 only
  -realtime REALTIME  real time data wanted? True or False. Default False
  -ts TIMESTART       start time like 2015-12-01. Default 1944-10-15
  -te TIMEEND         end time like 2018-06-30. Default today's date
  -out OUTFILELIST    name of the file to store the selected files urls.
                      Default: fileList.csv
"""


import sys
import argparse
from datetime import datetime, timedelta
from distutils.util import strtobool

from owslib.wfs import WebFeatureService
from owslib.fes import *
from owslib.etree import etree
import pandas as pd



def args():
    parser = argparse.ArgumentParser(description="Get a list of urls from the AODN geoserver")
    parser.add_argument('-var', dest='varname', help='name of the variable of interest, like TEMP', required=True)
    parser.add_argument('-site', dest='site', help='site code, like NRMMAI',  required=True)
    parser.add_argument('-ft', dest='featuretype', help='feature type, default timeseries', default='timeseries', required=False)
    parser.add_argument('-fv', dest='fileversion', help='file version 1 or 2 only', default=1, type=int, required=False)
    parser.add_argument('-ts', dest='timestart', help='start time like 2015-12-01. Default 1944-10-15', default='1944-10-15', required=False)
    parser.add_argument('-te', dest='timeend', help='end time like 2018-06-30. Default today\'s date', default=str(datetime.now())[:10], required=False)
    parser.add_argument('-out', dest='outFileList', help='name of the file to store the selected files urls. Default: filelist.csv', default="", required=False)
    parser.add_argument('-realtime', dest='realtime', help='real time data wanted?', required=False)

    vargs = parser.parse_args()
    return(vargs)


def get_urls(varname, site, featuretype='timeseries', fileversion=1, realtime='False', timestart='1944-10-15', timeend=str(datetime.now())[:10], outFileList=''):

    """
    get the urls from the geoserver moorings_all_map collection
    based on user defined filters
    """
    serverurl = 'http://geoserver-123.aodn.org.au/geoserver/wfs'
    ftype = 'imos:moorings_all_map'
    wfs = WebFeatureService(serverurl, version='1.1.0')

    ## filter first by site
    filter_site = PropertyIsLike(propertyname='site_code', literal=site)
    filter_xml = etree.tostring(filter_site.toXML()).decode("utf-8")
    response = wfs.getfeature(typename=ftype, filter=filter_xml,  outputFormat='csv')

    df = pd.read_csv(response)

    ## then filter by the rest of criteria
    criteria_var = df.variables.str.contains(varname, regex=False)
    criteria_fv = df.file_version == fileversion
    try:
        date_start = datetime.strptime(timestart, '%Y-%m-%d')
        date_end = datetime.strptime(timeend, '%Y-%m-%d')
    except ValueError:
        sys.exit('ERROR: invalid start or end date.')

    criteria_startdate = pd.to_datetime(df.time_coverage_start) >= date_start
    criteria_enddate = pd.to_datetime(df.time_coverage_end) <= date_end

    if realtime.lower()=='true':
        criteria_realtime = df.realtime==True
        criteria_all = criteria_var & criteria_realtime & criteria_fv & criteria_startdate & criteria_enddate
    else:
        criteria_realtime = df.realtime==False
        criteria_ft = df.feature_type.str.lower() == featuretype
        criteria_all = criteria_var & criteria_ft & criteria_realtime & criteria_fv & criteria_startdate & criteria_enddate

    if outFileList:
        df.url[criteria_all].to_csv(outFileList, index=False)

    return(df.url[criteria_all])


if __name__ == "__main__":
    vargs           = args()
    filenames = get_urls(**vars(vargs))
