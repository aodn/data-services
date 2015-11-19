#!/usr/bin/env python
#
# Return the correct path for an ANMN Acidification Moorings NetCDF
# file within the opendap filesystem


import os
import sys
from file_classifier import FileClassifier, FileClassifierException


class AnmnAmFileClassifier(FileClassifier):

    def dest_path(self, input_file):
        """
        Destination path for an Acidification Mooring file.  Returns
        "<site_code>/CO2/<mode>" where <mode> is "delayed" or
        "real-time"

        """
        # FileClassifier class gives path up to site_code
        dir_list = [FileClassifier.dest_path(self, input_file)]

        # add product sub-directory
        dir_list.append('CO2')

        # add real-time/delayed
        if 'delayed' in input_file:
            dir_list.append('delayed')
        elif 'realtime' in input_file:
            dir_list.append('real-time')
        else:
            raise FileClassifierException, \
                  "File '%s' is neither real-time nor delayed mode" % input_file

        return os.path.join(*dir_list)


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    input_path = sys.argv[1]

    try:
        fs = AnmnAmFileClassifier()
        dest_path = fs.dest_path(input_path)
    except FileClassifierException:
        exit(1)

    print dest_path
    exit(0)
