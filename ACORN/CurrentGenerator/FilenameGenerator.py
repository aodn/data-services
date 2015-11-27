#!/usr/bin/python

from datetime import datetime, timedelta
import argparse

import ACORNUtils

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--start", help="start time", required=True)
    parser.add_argument("-e", "--end", help="end time", required=True)
    parser.add_argument("-S", "--site", help="site", required=True)
    parser.add_argument("-q", "--qc", help="qc", action='store_true')
    args = parser.parse_args()

    timestampStart = datetime.strptime(args.start, "%Y%m%dT%H%M%S")
    timestampEnd = datetime.strptime(args.end, "%Y%m%dT%H%M%S")

    timestampIter = timestampStart
    while timestampIter <= timestampEnd:
        timestampIter = timestampIter + timedelta(hours=1)
        print ACORNUtils.generateCurrentFilename(args.site, timestampIter, args.qc)
