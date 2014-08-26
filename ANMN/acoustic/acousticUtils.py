#! /usr/bin/env python
#
# Useful functions for acoustic data.


import re
from datetime import datetime


def recordingStartTime(filename):
    """
    Read the start date/time from a raw acoustic recording file.
    Return as a datetime object.
    """
    f = open(filename)
    f.readline()  # 'Record Header'
    line = f.readline()
    m = re.findall('\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}', line)
    if not m:
        print 'recordingStartTime: No date on line 2 of file '+filename
        print 'line 2 is:\n'+line
        exit()
    return datetime.strptime(m[0], '%Y/%m/%d %H:%M:%S')
