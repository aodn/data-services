#!/usr/bin/python

import os, sys
import numpy as np
import tempfile
import shutil
from netCDF4 import Dataset
import logging
import warnings

import acorn_constants
import acorn_utils
import acorn_qc

class Util:
    @staticmethod
    def cos_degree(angle):
        return np.cos(np.radians(angle))

    @staticmethod
    def sin_degree(angle):
        return np.sin(np.radians(angle))

    @staticmethod
    def calc_u_vector(station_1_mean_speed, station_1_mean_dir, station_2_mean_speed, station_2_mean_dir):
        return (station_1_mean_speed * Util.cos_degree(station_2_mean_dir) - station_2_mean_speed * Util.cos_degree(station_1_mean_dir)) \
            / Util.sin_degree(station_1_mean_dir - station_2_mean_dir)

    @staticmethod
    def calc_v_vector(station_1_mean_speed, station_1_mean_dir, station_2_mean_speed, station_2_mean_dir):
        return (station_2_mean_speed * Util.sin_degree(station_1_mean_dir) - station_1_mean_speed * Util.sin_degree(station_2_mean_dir)) \
            / Util.sin_degree(station_1_mean_dir - station_2_mean_dir)

    @staticmethod
    def calc_u_error(station_1_mean_error, station_1_mean_dir, station_2_mean_error, station_2_mean_dir):
        return np.sqrt((station_2_mean_error ** 2 * Util.cos_degree(station_1_mean_dir) ** 2 + station_1_mean_error ** 2 * Util.cos_degree(station_2_mean_dir) ** 2) \
            / Util.sin_degree(station_1_mean_dir - station_2_mean_dir) ** 2)

    @staticmethod
    def calc_v_error(station_1_mean_error, station_1_mean_dir, station_2_mean_error, station_2_mean_dir):
        return np.sqrt((station_2_mean_error ** 2 * Util.sin_degree(station_1_mean_dir) ** 2 + station_1_mean_error ** 2 * Util.sin_degree(station_2_mean_dir) ** 2) \
            / Util.sin_degree(station_1_mean_dir - station_2_mean_dir) ** 2)

    @staticmethod
    def mean_error(error):
        tmp_error = np.array(error) # Copy array, so we don't overwrite it

        i_nan = np.isnan(tmp_error)
        i_all_nan = np.all(i_nan, axis=0)

        error_count = np.sum(-i_nan, axis=0, dtype=np.float32)
        error_count[i_all_nan] = np.nan # Avoid division by zero, set to nan

        return np.sqrt(np.nansum(np.power(tmp_error, 2), axis=0) / error_count)

    @staticmethod
    def has_enough_radials(radial_file_list):
        # Return True if each station has at least 3 radials
        retval = True
        for station, radial_files in radial_file_list.iteritems():
            logging.debug( "Station '%s' has '%d' radials available" % (station, len(radial_files)))
            if len(radial_files) < acorn_constants.WERA_MIN_RADIALS_PER_STATION:
                retval = False
                logging.warning("Not enough radials for station '%s', has '%d' but need at least '%d'" % (station, len(radial_files), acorn_constants.WERA_MIN_RADIALS_PER_STATION))

        return retval

    @staticmethod
    def get_radial_base(is_qc=False):
        if is_qc:
            return acorn_constants.RADIAL_QC_BASE
        else:
            return acorn_constants.RADIAL_BASE

    @staticmethod
    def get_existing_radials(radial_file_list, qc=False):
        return acorn_utils.get_existing_files(Util.get_radial_base(qc), radial_file_list)

    @staticmethod
    def prepare_radials(tmp_dir, radial_file_list, qc=False):
        return acorn_utils.prepare_files(tmp_dir, Util.get_radial_base(qc), radial_file_list)

    @staticmethod
    def get_radials_for_site(site, timestamp, qc=False):
        fileVersion = "00"
        if qc:
            fileVersion = "01"

        radials = {}
        site_description = acorn_utils.get_site_description(site, timestamp)
        for station in site_description['stations_order']:
            radials[station] = acorn_utils.files_for_station(station, timestamp, "RV", fileVersion, "radial")
        return radials

    @staticmethod
    def combine_radials(F, site, timestamp, radial_file_list, qc=False):
        max_speed = acorn_utils.get_site_description(site, timestamp)['max_speed']

        site_grid = acorn_utils.get_grid_for_site(site, timestamp, qc)
        site_lons = site_grid['lon']
        site_lats = site_grid['lat']
        lat_dim = len(site_lats)
        lon_dim = len(site_lons)

        if qc:
            logging.info("Using WERA QC")
            attribute_templating = acorn_constants.attribute_templating_wera_qc
        else:
            logging.info("Using WERA non-QC")
            attribute_templating = acorn_constants.attribute_templating_wera

        site_gdop = acorn_utils.get_gdop_for_site(site, timestamp, qc, lon_dim * lat_dim).reshape(lon_dim, lat_dim)

        # Do not pre fill with fill values this dataset, we do it ourselves
        F.set_fill_off()

        station_data = {}

        for station, radial_files in radial_file_list.iteritems():
            radial_count = len(radial_files)
            logging.info("Averaging '%d' radials for station '%s'" % (radial_count, station))

            station_data[station] = {}

            for var, dtype in acorn_constants.var_mapping_wera.iteritems():
                station_data[station][var] = np.full((len(radial_files), lon_dim, lat_dim), np.nan, dtype=dtype)

            i = 0
            for radial in radial_files:
                logging.debug("Extracting variables from '%s'" % radial)
                ds = Dataset(radial, mode='r')

                # Make POSITION a zero based (it starts from 1)
                pos_array = np.array(ds.variables['POSITION'])
                pos_array = pos_array - 1

                for var, dtype in acorn_constants.var_mapping_wera.iteritems():
                    tmp_array = acorn_utils.expand_array(
                        pos_array, ds.variables[var], lon_dim * lat_dim, dtype)

                    station_data[station][var][i] = tmp_array.reshape((lon_dim, lat_dim))

                ds.close()
                i = i + 1

        acorn_utils.fill_global_attributes(F, site, timestamp, qc, attribute_templating)

        acorn_qc.enforce_speed_limit(station_data, "ssr_Surface_Radial_Sea_Water_Speed", max_speed)

        acorn_qc.enforce_signal_to_noise_ratio(
            station_data,
            "ssr_Bragg_Signal_To_Noise",
            "ssr_Surface_Radial_Sea_Water_Speed_quality_control",
            qc
        )

        acorn_qc.discard_qc_range(
            station_data,
            "ssr_Surface_Radial_Sea_Water_Speed_quality_control",
            qc
        )

        acorn_qc.remove_low_observation_count(
            station_data,
            "ssr_Surface_Radial_Sea_Water_Speed"
        )

        acorn_qc.gdop_masking(
            station_data,
            site_gdop,
            "ssr_Surface_Radial_Sea_Water_Speed_quality_control",
            qc
        )

        speed_qc_max = np.zeros((lon_dim, lat_dim))

        for station in station_data.keys():
            station_data[station]["observation_count"] = np.sum(np.isfinite(station_data[station]["ssr_Surface_Radial_Sea_Water_Speed"]), axis=0)

            # Calculate mean of speed and direction variable over all stations
            # nanmean returns warning for empty slices, just suppress this as
            # this is the most elegant way to get rid of it:
            # http://stackoverflow.com/questions/29688168/mean-nanmean-and-warning-mean-of-empty-slice
            with warnings.catch_warnings():
                warnings.filterwarnings("ignore", "Mean of empty slice")
                station_data[station]["speed_mean"] = np.nanmean(station_data[station]["ssr_Surface_Radial_Sea_Water_Speed"], axis=0)
                station_data[station]["dir_mean"] = np.nanmean(station_data[station]["ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity"], axis=0)
                station_data[station]["bragg_mean"] = np.nanmean(station_data[station]["ssr_Bragg_Signal_To_Noise"], axis=0)

            # Take the highest QC value for every point
            tmpSpeedQcMax = np.amax(station_data[station]["ssr_Surface_Radial_Sea_Water_Speed_quality_control"], axis=0)
            speed_qc_max = np.maximum(
                speed_qc_max,
                tmpSpeedQcMax
            )

            station_data[station]["error_mean"] = Util.mean_error(station_data[station]["ssr_Surface_Radial_Sea_Water_Speed_Standard_Error"])

        station1 = acorn_utils.get_site_description(site, timestamp)['stations_order'][0]
        station2 = acorn_utils.get_site_description(site, timestamp)['stations_order'][1]

        # If there is no speed measurement in a point, set the QC flag to nan
        speed_qc_max[np.isnan(station_data[station1]["speed_mean"])] = np.nan
        speed_qc_max[np.isnan(station_data[station2]["speed_mean"])] = np.nan

        # Combine speed to get U and V
        ucur = Util.calc_u_vector(
            station_data[station1]["speed_mean"], station_data[station1]["dir_mean"],
            station_data[station2]["speed_mean"], station_data[station2]["dir_mean"]
        )

        vcur = Util.calc_v_vector(
            station_data[station1]["speed_mean"], station_data[station1]["dir_mean"],
            station_data[station2]["speed_mean"], station_data[station2]["dir_mean"]
        )

        ucur_sd = Util.calc_u_error(
            station_data[station1]["error_mean"], station_data[station1]["dir_mean"],
            station_data[station2]["error_mean"], station_data[station2]["dir_mean"]
        )

        vcur_sd = Util.calc_v_error(
            station_data[station1]["error_mean"], station_data[station1]["dir_mean"],
            station_data[station2]["error_mean"], station_data[station2]["dir_mean"]
        )

        # Enforce speed limit on U and V, if qc=1 or qc=2
        uSpeedExceeded = acorn_qc.get_exceeded_speed_limit(ucur, max_speed)
        logging.debug("Setting QC=3 on '%d' U values which exceeded speed limit of '%f'" % (np.sum(uSpeedExceeded), max_speed))
        speed_qc_max[uSpeedExceeded & ((speed_qc_max == 1) | (speed_qc_max == 2))] = 3

        vSpeedExceeded = acorn_qc.get_exceeded_speed_limit(vcur, max_speed)
        logging.debug("Setting QC=3 on '%d' V values which exceeded speed limit of '%f'" % (np.sum(vSpeedExceeded), max_speed))
        speed_qc_max[vSpeedExceeded & ((speed_qc_max == 1) | (speed_qc_max == 2))] = 3

        time_dimension = F.createDimension("TIME")
        latitude_dimension = F.createDimension("LATITUDE", lat_dim)
        longitude_dimension = F.createDimension("LONGITUDE", lon_dim)

        # TODO chunking of variables
        netcdf_vars = {}
        for var in acorn_constants.variable_order:
            netcdf_vars[var] = acorn_utils.add_netcdf_variable(F, var, acorn_constants.current_variables[var], attribute_templating)

        timezone = acorn_utils.get_site_description(site, timestamp)['timezone']
        netcdf_vars["TIME"].setncattr("local_time_zone", timezone)
        timestamp1950 = acorn_utils.days_since_1950(timestamp)

        netcdf_vars["TIME"][:] = [ timestamp1950 ]
        netcdf_vars["LATITUDE"][:] = site_lats
        netcdf_vars["LONGITUDE"][:] = site_lons

        netcdf_vars["GDOP"][:] = np.transpose(acorn_utils.nan_to_fill_value(site_gdop))

        netcdf_vars["UCUR"][0] = np.transpose(acorn_utils.nan_to_fill_value(ucur))
        netcdf_vars["VCUR"][0] = np.transpose(acorn_utils.nan_to_fill_value(vcur))

        netcdf_vars["UCUR_sd"][0] = np.transpose(acorn_utils.nan_to_fill_value(ucur_sd))
        netcdf_vars["VCUR_sd"][0] = np.transpose(acorn_utils.nan_to_fill_value(vcur_sd))

        # Number of observations
        netcdf_vars["NOBS1"][0] = np.transpose(
            acorn_utils.number_to_fill_value(station_data[station1]['observation_count'], acorn_constants.BYTE_FILL_VALUE)
        )
        netcdf_vars["NOBS2"][0] = np.transpose(
            acorn_utils.number_to_fill_value(station_data[station2]['observation_count'], acorn_constants.BYTE_FILL_VALUE)
        )

        # UCUR_quality_control and VCUR_quality_control are exactly the same
        netcdf_vars["UCUR_quality_control"][0] = netcdf_vars["VCUR_quality_control"][0] = np.transpose(
            acorn_utils.nan_to_fill_value(speed_qc_max, acorn_constants.BYTE_FILL_VALUE)
        )

def generate_current_from_radial_file(radialFile, dest_dir):
    """
    Main function to build a current out of a radial:
     * Determines whether there are enough radials
     * Download radials
     * Builds hoursly average product
    """

    site = acorn_utils.get_site_for_station(acorn_utils.get_station(radialFile))
    timestamp = acorn_utils.get_timestamp(radialFile)
    qc = acorn_utils.is_qc(radialFile)

    if qc:
        logging.info("We do nothing, ACORN UWA is in charge of generating hourly vector currents from '%s'" % radialFile)
        return acorn_utils.ACORNError.SUCCESS
    else:
        return generate_current(site, timestamp, qc, dest_dir)

def generate_current(site, timestamp, qc, dest_dir):
    timestamp = acorn_utils.get_current_timestamp(timestamp)

    dest_file = acorn_utils.generate_current_filename(site, timestamp, qc)
    dest_file = os.path.join(dest_dir, dest_file)

    logging.info("Destination file: '%s'" % dest_file)

    radial_file_list = Util.get_radials_for_site(site, timestamp, qc)
    radial_file_list = Util.get_existing_radials(radial_file_list, qc)

    if Util.has_enough_radials(radial_file_list):
        tmp_dir = tempfile.mkdtemp()

        radial_file_list = Util.prepare_radials(tmp_dir, radial_file_list, qc)

        fd, tmp_file = tempfile.mkstemp(prefix=os.path.join(dest_dir, "."))
        os.close(fd)
        F = Dataset(tmp_file, mode='w')
        Util.combine_radials(F, site, timestamp, radial_file_list, qc)
        F.close()

        shutil.rmtree(tmp_dir)
        logging.debug("Renaming '%s' -> '%s'" % (tmp_file, dest_file))
        os.chmod(tmp_file, 0444)
        os.rename(tmp_file, dest_file)
        logging.info("Wrote file '%s'" % dest_file)
        return acorn_utils.ACORNError.SUCCESS
    else:
        logging.error("Not enough radials for file '%s'" % dest_file)
        return acorn_utils.ACORNError.NOT_ENOUGH_FILES
