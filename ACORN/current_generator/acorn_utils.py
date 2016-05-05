#!/usr/bin/python

import os, sys
import urllib2
from multiprocessing import Pool
from string import Template
import numpy as np
from datetime import datetime, timedelta
import acorn_constants
import logging

class Enum(set):
    def __getattr__(self, name):
        if name in self:
            return name
        raise AttributeError

ACORNError = Enum(["NOT_ENOUGH_FILES", "ERROR", "SUCCESS"])

def file_parts(f):
    return f.split(acorn_constants.DELIMITER)

def get_data_path():
    return os.path.join(os.path.dirname(os.sys.argv[0]), "..")

def download_file_parallel_wrapper(args):
    """
    Helper function when using parallel mode downloading as the multiprocessing
    module is a bit lame and has difficulties passing multiple parameters to a
    function
    """
    return download_file(*args)

def download_file(url, target=None):
    """
    Downloads a file. If a target is not specified, this function can be used
    to decide whether a url is "download-able".
    """
    try:
        if target is not None:
            logging.info("Downloading '%s' -> '%s'" % (url, target))

        u = urllib2.urlopen(url)

        if target is not None:
            f = open(target, 'wb')
            f.write(u.read())
            f.close()

        logging.info("'%s' - OK" % url)
        return True
    except urllib2.HTTPError, e:
        if e.code == 404:
            logging.debug("Could not download '%s', '%s'" % (url, e.code))
        else:
            logging.error("Could not download '%s', '%s'" % (url, e.code))
    except urllib2.URLError, e:
        logging.error("Could not download '%s', '%s'" % (url, e.args))

    return False

def files_for_station(station, timestamp, file_flags, file_version, file_type):
    files =[]
    for ts in get_timestamp_for_current(timestamp):
        fBasename = gen_filename(station, ts, file_flags, file_version, file_type)
        f = os.path.join(
            station,
            str(ts.year).zfill(4),
            str(ts.month).zfill(2),
            str(ts.day).zfill(2),
            fBasename
        )
        files.append(f)

    return files

def gen_filename(name, timestamp, parameter_code, file_version, suffix):
    return "%s%s%s%s%s%s%s%sFV%s%s%s.nc" % (
        acorn_constants.FACILITY_PREFIX, acorn_constants.DELIMITER,
        parameter_code, acorn_constants.DELIMITER,
        timestamp.strftime(acorn_constants.DATE_TIME_FORMAT), acorn_constants.DELIMITER,
        name, acorn_constants.DELIMITER,
        file_version, acorn_constants.DELIMITER, suffix
    )

def generate_current_filename(site_name, timestamp, qc=False):
    file_version = "00"
    if qc:
        file_version = "01"

    return gen_filename(site_name, timestamp, "V", file_version, "1-hour-avg")

def get_file_type(f):
    parts = file_parts(f)
    if len(parts) >= 7:
        return parts[6][:-3]

def is_radial(f):
    return get_file_type(f) == "radial"

def is_vector(f):
    return get_file_type(f) == "sea-state"

def is_qc(f):
    return get_file_version(f) == "FV01"

def is_hourly(f):
    return get_file_type(f) == "1-hour-avg"

def days_since_1950(timestamp):
    return (timestamp - datetime.strptime("19500101T000000Z", "%Y%m%dT%H%M%SZ")).total_seconds() / (60 * 60 * 24)

def get_file_version(f):
    return file_parts(f)[5]

def get_timestamp(f):
    return datetime.strptime(file_parts(f)[3], acorn_constants.DATE_TIME_FORMAT)

def get_station(f):
    return file_parts(f)[4]

def site_filename(site, timestamp, qc):
    # For QC mode, sites has the same grid
    if qc:
        return site

    site_description = get_site_description(site, timestamp)

    file_suffix = ""
    if 'file_suffix' in site_description:
        file_suffix = site_description['file_suffix']


    return "%s%s" % (site, file_suffix)

def get_gdop_file(site, timestamp, qc):
    station_type = get_site_description(site, timestamp)['type']
    return os.path.join(get_data_path(), station_type, "%s.gdop" % site_filename(site, timestamp, qc))

def get_grid_file_codar(site, timestamp, qc):
    # Relevant only for CODAR
    station_type = get_site_description(site, timestamp)['type']
    return os.path.join(get_data_path(), station_type, "grid_%s.dat" % site_filename(site, timestamp, qc))

def get_lat_file_wera(site, timestamp, qc):
    # Relevant only for WERA
    station_type = get_site_description(site, timestamp)['type']
    return os.path.join(get_data_path(), station_type, "LAT_%s.dat" % site_filename(site, timestamp, qc))

def get_lon_file_wera(site, timestamp, qc):
    # Relevant only for WERA
    station_type = get_site_description(site, timestamp)['type']
    return os.path.join(get_data_path(), station_type, "LON_%s.dat" % site_filename(site, timestamp, qc))

def number_to_fill_value(d, fill_value=acorn_constants.FLOAT_FILL_VALUE, number=0):
    d[d==number] = fill_value
    return d

def nan_to_fill_value(d, fill_value=acorn_constants.FLOAT_FILL_VALUE):
    d[np.isnan(d)] = fill_value
    return d

def get_gdop_for_site(site, timestamp, qc, dimension):
    gdop = np.full(dimension, fill_value=np.nan, dtype=np.float)
    i = -1
    with open(get_gdop_file(site, timestamp, qc)) as f:
        for line in f.readlines():
            if i > -1: # Skip first line
                gdop[i] = np.float(line.split()[4])
            i += 1
    return gdop


def get_grid_for_site(site, timestamp, qc):
    station_type = get_site_description(site, timestamp)['type']

    if station_type == "WERA":
        return get_grid_for_site_wera(site, timestamp, qc)
    elif station_type == "CODAR":
        return get_grid_for_site_codar(site, timestamp, qc)
    else:
        logging.error("Cannot get grid for site '%s', unknown type" % site)
        exit(1)

def get_grid_for_site_wera(site, timestamp, qc):
    """
    This returns a hash with arrays corresponding to lon and lat dimensions
    """

    grid = {}
    with open(get_lon_file_wera(site, timestamp, qc)) as f:
        lines = f.readlines()
    grid['lon'] = [np.float64(i) for i in lines]

    with open(get_lat_file_wera(site, timestamp, qc)) as f:
        lines = f.readlines()
    grid['lat'] = [np.float64(i) for i in lines]

    return grid

def get_grid_for_site_codar(site, timestamp, qc):
    """
    CODAR has one file with all the grid points that are not aligned to U and V
    This function returns a hash with 2 arrays (lon, lat) that are aligned
    """
    grid = {
        "lon": [],
        "lat": []
    }

    with open(get_grid_file_codar(site, timestamp, qc)) as f:
        lines = f.readlines()

    for line in lines:
        grid['lon'].append(np.float64(line.split("\t")[0]))
        grid['lat'].append(np.float64(line.split("\t")[1]))

    return grid

def get_site_for_station(station):
    for site, site_description in acorn_constants.site_descriptions.iteritems():
        if station in site_description['stations_order']:
            return site

    return None

def expand_array(pos_array, var_array, dim, dtype=np.int):
    """
    Return an expanded array, fitting values from var_array[pos_array] and
    filling nans where there are no values. pos_array needs to be zero based
    however the radials are not zero based, so fix the array beforehand
    """

    result_array = np.full(dim, fill_value=np.nan, dtype=dtype)
    try:
        result_array[pos_array] = np.array(var_array)
    except:
        logging.error("Error expanding array, max POS value is '%d', array size is '%d'" % (max(pos_array), dim))
        exit(1)

    # This is a non vectorized version, which does the same, left for clarity
    #for i in range(0, len(pos_array)):
    #    # pos_array will not be 0 based, so make it zero based
    #    result_array[pos_array[i] - 1] = var_array[i]

    return result_array

def add_netcdf_variable(F, var_name, var_info, attribute_templating):
    fill_value = False
    if 'fill_value' in var_info:
        fill_value = var_info['fill_value']

    new_var = F.createVariable(
        var_name, var_info['dtype'], var_info['dimensions'],
        zlib=True, complevel=acorn_constants.NETCDF_COMPRESSION_LEVEL,
        fill_value=fill_value)

    for variableAttribute in var_info['attributes']:
        # Allow some templating for strings
        variableAttributeValue = variableAttribute[1]
        if isinstance(variableAttributeValue, basestring):
            variableAttributeValue = Template(variableAttribute[1]).substitute(attribute_templating)

        new_var.setncattr(
            variableAttribute[0],
            variableAttributeValue
        )

    return new_var

def get_current_timestamp(timestamp):
    return timestamp.replace(minute=30, second=0, microsecond=0)

def get_site_description(site, timestamp):
    site_description = acorn_constants.site_descriptions[site].copy()

    if 'overrides' in site_description:
        for override in site_description['overrides']:
            time_start = datetime.strptime(override['time_start'], "%Y%m%dT%H%M%S")
            time_end = datetime.strptime(override['time_end'], "%Y%m%dT%H%M%S")

            if timestamp > time_start and timestamp <= time_end:
                site_description.update(override['attributes'])
                
    return site_description

def fill_global_attributes(F, site, timestamp, qc, attribute_templating):
    date_time_format = "%Y-%m-%dT%H:%M:%SZ"

    site_description = get_site_description(site, timestamp)

    station_string = ""
    for station in site_description['stations_order']:
        station_string += "%s (%s), " % (site_description['stations'][station]['name'], station)
    station_string = station_string[:-2]

    site_grid = get_grid_for_site(site, timestamp, qc)
    site_lons = site_grid['lon']
    site_lats = site_grid['lat']

    # Merge all specific attributes from station/site type (i.e. WERA, CODAR)
    station_type = site_description['type']

    attribute_templating['siteLongName']      = site_description['name']
    attribute_templating['site']              = site
    attribute_templating['stations']          = station_string
    attribute_templating['station_type']      = station_type
    attribute_templating['timeCoverageStart'] = timestamp.strftime(date_time_format)
    attribute_templating['timeCoverageEnd']   = timestamp.strftime(date_time_format)
    attribute_templating['stations']          = station_string
    attribute_templating['dateCreated']       = datetime.utcnow().strftime(date_time_format)

    # Override some attributes with station specific values that are not
    # templated strings
    attribute_templating['geospatial_lat_min'] = float(min(site_lats))
    attribute_templating['geospatial_lat_max'] = float(max(site_lats))
    attribute_templating['geospatial_lon_min'] = float(min(site_lons))
    attribute_templating['geospatial_lon_max'] = float(max(site_lons))
    attribute_templating['local_time_zone']    = site_description["timezone"]

    for global_attribute in acorn_constants.global_attributes:
        global_attribute_name, global_attribute_value = global_attribute

        if global_attribute_name in attribute_templating:
            global_attribute_value = attribute_templating[global_attribute_name]
        elif isinstance(global_attribute_value, basestring):
            # Allow templating for strings
            global_attribute_value = Template(global_attribute[1]).substitute(attribute_templating)

        if global_attribute_value is not None:
            F.setncattr(global_attribute[0], global_attribute_value)

def http_link(base, f):
    return os.path.join(acorn_constants.HTTP_BASE, acorn_constants.ACORN_BASE, base, f)

def prepare_files(tmp_dir, base, file_list, max_threads=6):
    files = {}
    for station, station_files in file_list.iteritems():
        urls = []
        cached_paths = []
        for f in station_files:
            url = http_link(base, f)
            cached_path = os.path.join(tmp_dir, os.path.basename(f))
            urls.append((url, cached_path))
            cached_paths.append(cached_path)

        p = Pool(max_threads)
        cached_paths = np.array(cached_paths)
        results = np.array(p.map(download_file_parallel_wrapper, urls))
        files[station] = list(cached_paths[results])

    return files

def get_existing_files(base, file_list, max_threads=6):
    existing_files = {}
    for station, files in file_list.iteritems():
        urls = []
        for f in files:
            urls.append(http_link(base, f))

        p = Pool(max_threads)
        files = np.array(files)
        results = np.array(p.map(download_file, urls))
        existing_files[station] = list(files[results])

    return existing_files

def get_timestamp_for_current(timestamp):
    """
    Return all possible timestamps to calculate the average hourly from.
    Basically returns a time delta every 5 minutes starting from 0 minutes
    until 55 minutes of the hour.
    """

    time_start = timestamp.replace(minute=0)
    time_end = time_start + timedelta(hours=1)
    time_range = []

    time_iter = time_start
    while (time_iter < time_end):
        time_range.append(time_iter)
        time_iter = time_iter + timedelta(minutes=acorn_constants.STATION_FREQUENCY_MINUTES)

    return time_range
