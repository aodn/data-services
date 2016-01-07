#!/usr/bin/python

from datetime import datetime, timedelta
import argparse

import acorn_utils

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--start", help="start time", required=True)
    parser.add_argument("-e", "--end", help="end time", required=True)
    parser.add_argument("-S", "--site", help="site", required=True)
    parser.add_argument("-q", "--qc", help="qc", action='store_true')
    args = parser.parse_args()

    timestamp_start = datetime.strptime(args.start, "%Y%m%dT%H%M%S")
    timestamp_end = datetime.strptime(args.end, "%Y%m%dT%H%M%S")

    timestamp_iter = timestamp_start
    while timestamp_iter <= timestamp_end:
        timestamp_iter = timestamp_iter + timedelta(hours=1)
        print acorn_utils.generate_current_filename(args.site, timestamp_iter, args.qc)
