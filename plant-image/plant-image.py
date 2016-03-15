#!/usr/bin/python

import os, sys
import numpy as np
import tempfile
import shutil
from netCDF4 import Dataset
import logging
import warnings
from PIL import Image
from datetime import datetime, timedelta
from scipy import misc

# wget https://imos-data.s3-ap-southeast-2.amazonaws.com/IMOS/SRS/SST/ghrsst/L3U/n19/2015/20151231145731-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Des.nc
# ./plant-image.py 20151231145731-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Des.nc gone-skiing-srs.png 19500101000000-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Des.nc

# Does not scale image, it must be 6000x4500
image_width = 6000
image_height = 4500

target_variable_type = np.short
target_variable_name = "sea_surface_temperature"
target_variable_fill_value = -32768
target_variable_value = 1468

DATE_TIME_FORMAT = "%Y%m%d%H%M%SZ"

def seconds_since_1981(timestamp):
    return (timestamp - datetime.strptime("19810101000000Z", DATE_TIME_FORMAT)).total_seconds()

time_attributes = [
    "start_time",
    "time_coverage_start",
    "stop_time",
    "time_coverage_end",
]

attrs_remove = [
    "publisher_name",
    "publisher_email",
]

attrs_add = [

    [ "publisher_name", "Dan Fruehauf" ],
    [ "publisher_email", "malkodan@gmail.com" ],
    [ "publisher_facebook", "https://www.facebook.com/dan.fruehauf" ],

    [ "_01_farewell",                 "Dear IMOS," ],
    [ "_02_farewell",                 "" ],
    [ "_03_farewell",                 "Still, almost 3 years after I was hired to this role I do not understand why the risk of hiring me was taken. But I guess no one knew at the time..." ],
    [ "_04_farewell",                 "" ],
    [ "_05_farewell",                 "Thanks for giving me the opportunity to build something for the better good - even though I mostly deleted stuff instead of building. Leaving IMOS at this time gives me a bit of closure as the first project at IMOS was putting together the bits and pieces of what was the Data Fabric. I'm leaving IMOS knowing that the data on S3 is secure and I believe it is a really good long term plan, especially with budget being planned for 5 years ahead." ],
    [ "_06_farewell",                 "" ],
    [ "_07_farewell",                 "From a personal perspective I felt it is time for me to move on towards new challenges. Now that I am a permanent resident in Australia more opportunities are open for me. However I am going to spend the near future with my family in Israel and then skiing/climbing in NZ. Wish me good powder." ],
    [ "_08_farewell",                 "" ],
    [ "_09_farewell",                 "Special thanks need to go to Pete, who managed to put up with me for that period of time and I know I'm not an easy person to deal with." ],
    [ "_10_farewell",                 "" ],
    [ "_11_farewell",                 "If you wish to stay in contact, my email and facebook are also in the global attributes of this NetCDF file." ],
    [ "_12_farewell",                 "" ],
    [ "_13_farewell",                 "Cheers and cya around!" ],
    [ "_14_farewell",                 "" ],
    [ "_15_farewell",                 "" ],
    [ "_16_farewell",                 "P.S. Storing this NetCDF file will cost IMOS roughly A$0.006 a year (based on prices from March 2016)." ],
]

if __name__ == '__main__':
    src_file = sys.argv[1]
    img_file = sys.argv[2]
    dst_file = sys.argv[3]

    timestamp_str = dst_file.split("-")[0] + "Z"
    timestamp = datetime.strptime(timestamp_str, DATE_TIME_FORMAT)

    shutil.copy(src_file, dst_file)
    ds_out = Dataset(dst_file, mode='r+')

    for attr in time_attributes:
        print "Setting time attribut '%s' -> '%s'" % (attr, timestamp_str)
        ds_out.setncattr(attr, timestamp_str)

    for attr in attrs_remove:
        print "Removing attribute '%s'" % attr
        ds_out.delncattr(attr)

    for attr in attrs_add:
        print "Setting attribute '%s' -> '%s'" % (attr[0], attr[1])
        ds_out.setncattr(attr[0], attr[1])

    print "Plainting image '%s'" % img_file
    img_data = np.full((image_height, image_width), fill_value=target_variable_fill_value, dtype=target_variable_type)

    image = np.asarray(Image.open(img_file))

    iTransparent = np.all(image == [0, 0, 0, 0], axis=2)
    img_data[~iTransparent] = target_variable_value

    ds_out['l2p_flags'].delncattr('flag_masks') # Make CF compliant!

    ds_out[target_variable_name][0] = img_data
    ds_out["time"][0] = seconds_since_1981(timestamp)

    print "Saving file as '%s'" % dst_file
    ds_out.close()
