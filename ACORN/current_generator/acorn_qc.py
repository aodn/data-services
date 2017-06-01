#!/usr/bin/python

import logging

import numpy as np

import acorn_constants
import acorn_utils


"""
The station_data struct is something that looks like:
station_data = {
    "station1": {
        "speed": np.array([...]),
        "error": np.array([...]),
        ...
    },
    "station2": {
        "speed": np.array([...]),
        "error": np.array([...]),
        ...
    }
}
"""

def nan_all(station_data, station, pos):
    """
    Fill NaNs in all given indices for station_data struct, iterating on all
    matrices of station_data

    @type station_data: dict
    @param station_data: Hash with all site/station data. Modified in place

    @type station: station
    @param station: Station key to null values for

    @type pos: np.array
    @param pos: Array mask with True where values should become NaN
    """
    for k, matrix in station_data[station].iteritems():
        matrix[pos] = np.nan

def remove_low_observation_count(station_data, speed_key, min_observations=acorn_constants.WERA_MIN_RADIALS_PER_STATION):
    """
    Fill NaNs in all indices with not enough observation count

    @type station_data: dict
    @param station_data: Hash with all site/station data. Modified in place

    @type speed_key: string
    @param speed_key: Speed hash key in hash

    @type min_observations: int
    @param min_observations: Threshold for low observations
    """

    for station in station_data.keys():
        obs_count = np.sum(np.isfinite(station_data[station][speed_key]), axis=0)

        i_not_enough_obs = obs_count < min_observations
        logging.info("Removed '%d' values with observations < '%d'" % (np.sum(i_not_enough_obs), min_observations))
        i_not_enough_obs = np.expand_dims(i_not_enough_obs, axis=0)

        # NAN all stations, not just the inspected station
        for stn in station_data.keys():
            xAxis = station_data[stn][speed_key].shape[0]
            i_not_enough_obs_mask = np.repeat(i_not_enough_obs, xAxis, axis=0)
            nan_all(station_data, stn, i_not_enough_obs_mask)

def get_exceeded_speed_limit(speed, max_speed):
    """
    Return all indices with speed limit exceeding max_speed, ignoring NaNs

    @type speed: np.array
    @param speed: Array with speed values

    @type speed_key: string
    @param speed_key: Speed hash key in hash

    @type max_speed: float
    @param max_speed: Maximum speed

    @rtype: np.array
    @return: Array with True values where speed limit exceeded
    """
    speedAbs = np.abs(np.nan_to_num(speed))
    return speedAbs >= max_speed

def enforce_speed_limit(station_data, speed_key, max_speed):
    """
    Fill NaNs where speed limit is exceeded

    @type station_data: dict
    @param station_data: Hash with all site/station data. Modified in place

    @type speed_key: string
    @param speed_key: Speed hash key in hash

    @type max_speed: float
    @param max_speed: Maximum speed
    """

    for station in station_data.keys():
        speed_matrix = np.array(station_data[station][speed_key])
        i_speed_exceeded = get_exceeded_speed_limit(speed_matrix, max_speed)

        logging.info("Removed '%d' values which exceeded speed limit of '%f'" % (np.sum(i_speed_exceeded), max_speed))
        nan_all(station_data, station, i_speed_exceeded)

def enforce_signal_to_noise_ratio(station_data, bragg_key, qc_key, qc_mode=False, min_bragg=8.0, suspicious_bragg=10.0):
    """
    Enforce signal to noise ratio. Fill NaNs where values are smaller than
    min_bragg.
    Set QC flag to 2 where min_bragg <= value < suspicious_bragg and QC flag == 1
    if qc_mode==True.

    @type station_data: dict
    @param station_data: Hash with all site/station data. Modified in place

    @type bragg_key: string
    @param bragg_key: Bragg key in hash

    @type qc_key: string
    @param qc_key: QC key in hash

    @type min_bragg: float
    @param min_bragg: Minimum bragg, below that, set values to NaN

    @type min_bragg: float
    @param suspicious_bragg: Suspicious bragg, below that, set QC flag to 2
    """

    for station in station_data.keys():
        bragg_matrix = np.array(station_data[station][bragg_key])
        qc_matrix = np.array(station_data[station][qc_key])

        # Ignore nans for both matrices
        bragg_matrix[np.isnan(bragg_matrix)] = np.inf
        qc_matrix[np.isnan(qc_matrix)] = np.inf

        i_low_bragg = min_bragg > bragg_matrix
        logging.info("Removed '%d' values with bragg < '%f'" % (np.sum(i_low_bragg), min_bragg))

        nan_all(station_data, station, i_low_bragg)

        if qc_mode:
            i_good_qc = qc_matrix == 1
            i_suspicious_bragg_with_good_qc = (bragg_matrix < suspicious_bragg) & (i_good_qc)

            logging.info("Setting QC=2 on '%d' values with bragg < '%f' and QC == 1" % (np.sum(i_suspicious_bragg_with_good_qc), suspicious_bragg))
            station_data[station][qc_key][i_suspicious_bragg_with_good_qc] = 2

def discard_qc_range(station_data, qc_key, qc_mode=False, min_qc=1, max_qc=2):
    """
    Fill NaNs for every value that does not meet max_qc >= QC >= min_qc.
    Notice you have to pass qc_mode=True for this function to do anything!!

    @type station_data: dict
    @param station_data: Hash with all site/station data. Modified in place

    @type min_qc: int
    @param min_qc: Lower end of QC range (usually 1)

    @type max_qc: int
    @param max_qc: Upper end of QC range (usually 2)
    """

    if not qc_mode:
        return

    for station in station_data.keys():
        qc_matrix = station_data[station][qc_key]
        qc_matrix[np.isnan(qc_matrix)] = min_qc # Treat all nan values as good
        i_good_qc = (min_qc <= qc_matrix) & (qc_matrix <= max_qc)
        i_bad_qc = -i_good_qc

        logging.info("Removed '%d' values, leaving only values with '%d' <= QC <= '%d'" % (np.sum(i_bad_qc), min_qc, max_qc))
        nan_all(station_data, station, i_bad_qc)

def gdop_masking(station_data, gdop, qc_key, qc_mode=False, bad_gdop=20, suspicious_gdop=30, bad_flag=4, suspicious_flag=3):
    """
    Set QC flags for every value that has a problematic GDOP angle.
    In non-QC mode set a default value of 0, in QC mode set it to 1.

    A problematic GDOP is when the angle betwen the radials is too small to get
    an accurate measurement. That is values of -20 < x < 20 or x > 160 or
    x < -160. In those cases the radials are /almost/ at the same angle, and
    each of them does not necessarily give more information compared to having
    just one radial.

    When the GDOP angle is under the bad_gdop range, QC flag will set to 4, in
    angles that are bad_gdop < x < suspicious_gdop, the flag will be set to 3.

    This function expands the GDOP array to be a matrix like in station_data and
    then masks the station_data with the GDOP matrix.

    @type station_data: dict
    @param station_data: Hash with all site/station data. Modified in place

    @type gdop: np.array
    @param gdop: Numpy array with all GDOP angles. gdop[x] corresponds to
                 station_data[station][qc_key][x]

    @type qc_mode: bool
    @param qc_mode: In QC mode the default QC flag is 1, 0 otherwise

    @type bad_gdop: float
    @param bad_gdop: Bad GDOP, set QC flag to 4

    @type suspicious_gdop: float
    @param suspicious_gdop: Suspicious GDOP, set QC flag to 3
    """

    # Set an array with the distance of GDOP from 0 or 180
    # For instance, the "fate" of a 165 angle is the same as 15
    # Or, 130 and 50, etc. You get the idea...
    gdop_normalized = np.minimum(np.abs(180 - gdop), np.abs(0 - gdop))

    i_bad_gdop = gdop_normalized <= bad_gdop
    i_suspicious_gdop = (bad_gdop < gdop_normalized) & (gdop_normalized <= suspicious_gdop)

    logging.info("Setting QC='%d' on '%d' values with '%f' < GDOP <= '%f'" % (suspicious_flag, np.sum(i_suspicious_gdop), bad_gdop, suspicious_gdop))
    logging.info("Setting QC='%d' on '%d' values with GDOP <= '%f'" % (bad_flag, np.sum(i_bad_gdop), bad_gdop))

    # In QC mode, default GDOP QC will be 1
    # Otherwise use 0 by default (no QC)
    if qc_mode:
        default_qc_value = 1
    else:
        default_qc_value = 0

    gdop_qc_mask = np.full(gdop_normalized.shape, default_qc_value, dtype=np.byte)

    gdop_qc_mask[i_suspicious_gdop] = suspicious_flag
    gdop_qc_mask[i_bad_gdop] = bad_flag

    for station in station_data.keys():
        qc_matrix = station_data[station][qc_key]

        qc_matrix = np.maximum(qc_matrix, gdop_qc_mask)

        # All nans can become zeros or ones, depending on qc_mode
        qc_matrix[np.isnan(qc_matrix)] = default_qc_value

        station_data[station][qc_key] = qc_matrix
