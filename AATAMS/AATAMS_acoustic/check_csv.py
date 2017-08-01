#!/usr/bin/env python
"""
Run checks on csv:
    - file has required fields
    - fields or of expected type
"""
import os
import pandas
import sys
import numpy

EXPECTED_HEADERS = {'transmitter_id', 'installation_name', 'station_name', 'receiver_name', 'detection_timestamp',
                    'longitude', 'latitude', 'sensor_value', 'sensor_unit', 'FDA_QC', 'Velocity_QC', 'Distance_QC',
                    'DetectionDistribution_QC', 'DistanceRelease_QC', 'ReleaseDate_QC', 'ReleaseLocation_QC',
                    'Detection_QC'}


def main(csvfile):
    # CSV file to extract array of formatted data
    data = pandas.read_csv(csvfile, delimiter=';', header=0)

    # QC columns must be all integer
    if not all(data.filter(regex='_QC').dtypes == numpy.int64()):
        listcol = data.filter(
            regex='_QC').loc[:, (data.dtypes != numpy.int64())].columns
        sys.exit("Misssing value or incorrect data type in file '{csvfile}'. Columns type '{listcol}'".format(
            csvfile=csvfile, listcol=listcol))

    # check that file has all expected columns
    actual_headers = set(data.columns.values)

    # compare expected with actual headers, do nothing if they are equal
    if actual_headers != EXPECTED_HEADERS:
        only_in_actual = list(actual_headers.difference(EXPECTED_HEADERS))
        only_in_expected = list(EXPECTED_HEADERS.difference(actual_headers))

        error_message = [
            "Columns in file '{csvfile}' don't match expected columns".format(csvfile=csvfile)]
        # print report on what the differences were between the
        # expected headers and the actual headers
        if only_in_actual:
            error_message.append("Unexpected columns: {only_in_actual}".format(
                only_in_actual=only_in_actual))
        if only_in_expected:
            error_message.append("Missing columns: {only_in_expected}".format(
                only_in_expected=only_in_expected))

        sys.exit(os.linesep.join(error_message))


if __name__ == '__main__':
    try:
        input_file = sys.argv[1]
    except IndexError:
        sys.exit("usage: {script} CSVFILE".format(script=sys.argv[0]))
    main(input_file)
