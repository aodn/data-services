#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Oct  7 11:45:44 2014
This script downloads a lev20 file (CSV) and unzip it in the IMOS public folder
/SRS/SRS-OC-LJCO/AERONET

@author: lbesnard
laurent.besnard@utas.edu.au
"""

import glob
import os
import re
import shutil
import sys
import zipfile
from io import BytesIO
from tempfile import mkdtemp, mkstemp

from bs4 import BeautifulSoup
from contextlib import closing
from six.moves.urllib.request import urlopen

from imos_logging import IMOSLogging

NASA_LEV2_URL = "http://aeronet.gsfc.nasa.gov/cgi-bin/print_warning_opera_v2_new?site=Lucinda&year=110&month=6&day=1&year2=110&month2=6&day2=30&LEV20=1&AVG=10"

def download_ljco_aeronet(download_dir):
    logger.info('Open NASA webpage')
    with closing(urlopen(NASA_LEV2_URL)) as response:
        html = response
        htmlPageSoup = BeautifulSoup(html.read(), 'html.parser')

    # scrap webpage to find zip file address
    webpageBase, value = NASA_LEV2_URL.split("/cgi-bin", 1)
    for link in htmlPageSoup.findAll('a', attrs={'href': re.compile("^.zip")}):
        dataWebLink = webpageBase + link.get('href')

    logger.info('Downloading AERONET data')
    url_data_object = urlopen(dataWebLink)
    temp_dir        = mkdtemp()

    with zipfile.ZipFile(BytesIO(url_data_object.read())) as zip_data:
        zip_data.extractall(temp_dir)

    data_file    = glob.glob('%s/*Lucinda.lev20' % temp_dir)[0]

    logger.info('Cleaning AERONET data')
    f        = open(data_file, 'r')
    filedata = f.read()
    f.close()

    replaced_data = filedata.replace("N/A", "")

    os.umask(0o002)
    f = open(data_file, 'w')
    f.write(replaced_data)
    f.close()

    if os.path.exists(download_dir):
        shutil.move(data_file, os.path.join(download_dir, 'Lucinda.lev20'))
    else:
        logger.error('%s does not exists' % download_dir)

    shutil.rmtree(temp_dir)


if __name__ == "__main__":
    logging = IMOSLogging()
    log_file = [mkstemp()]
    global logger
    logger = logging.logging_start(log_file[0][1])

    try:
        download_ljco_aeronet(sys.argv[1])
    except Exception as err:
        print(err)

    logging.logging_stop()
    os.close(log_file[0][0])
    os.remove(log_file[0][1])
