#!/usr/bin/python

import os, sys
import numpy as np
import tempfile
import shutil
from datetime import datetime, timedelta
from netCDF4 import Dataset
import logging

import acorn_constants
import acorn_utils
import acorn_qc

class Util:
    @staticmethod
    def has_enough_vectors(radialFileList):
        # We will have only 1 station and 1 file... :)
        for station, radialFiles in radialFileList.iteritems():
            return len(radialFiles) > 0

    @staticmethod
    def get_vector_base():
        return acorn_constants.VECTOR_BASE

    @staticmethod
    def get_existing_vectors(vector_file_list):
        return acorn_utils.get_existing_files(Util.get_vector_base(), vector_file_list)

    @staticmethod
    def prepare_vectors(tmp_dir, vector_file_list):
        return acorn_utils.prepare_files(tmp_dir, Util.get_vector_base(), vector_file_list)

    @staticmethod
    def get_vectors_for_site(site, timestamp):
        vectors = {}
        station = site # Station sending files is equal to the site name
        vectors[station] = [ acorn_utils.files_for_station(station, timestamp, "V", "00", "sea-state")[0] ]
        return vectors

    @staticmethod
    def adjust_grid(data, lon_dim, lat_dim):
        """
        Data on the CODAR grid is ordered from bottom left to top right and we
        need it ordered so a reshape and reversing along the Y axis is required
        """
        shaped_data = np.reshape(data, (lat_dim, lon_dim))

        # After the array is shaped, we reverse it along the Y axis
        shaped_data = np.flipud(shaped_data)

        # Return it as a 1 dimensional array
        return shaped_data.reshape((1, lon_dim * lat_dim))[0]

    @staticmethod
    def fix_gdop_grid(gdop, lon_dim, lat_dim):
        # Fix gdop grid to align properly. It is stored awkwardly in the first
        # place
        return np.transpose(gdop.reshape((lon_dim, lat_dim))).flatten().reshape((lon_dim, lat_dim))

    @staticmethod
    def transform_vector(F, site, timestamp, vector_file_list):
        site_description = acorn_utils.get_site_description(site, timestamp)
        lat_dim = site_description['dimensions']['lat']
        lon_dim = site_description['dimensions']['lon']
        array_size = lat_dim * lon_dim

        site_grid = acorn_utils.get_grid_for_site(site, timestamp, False)

        site_lons = Util.adjust_grid(site_grid['lon'], lon_dim, lat_dim)
        site_lats = Util.adjust_grid(site_grid['lat'], lon_dim, lat_dim)

        site_gdop = acorn_utils.get_gdop_for_site(site, timestamp, False, lon_dim * lat_dim)
        site_gdop = Util.fix_gdop_grid(site_gdop, lon_dim, lat_dim)

        attribute_templating = acorn_constants.attribute_templating_codar

        # Do not pre fill with fill values this dataset, we do it ourselves
        F.set_fill_off()

        station_data = {}

        station = vector_file_list.keys()[0]
        sourceVectorFile = vector_file_list[station][0]

        station_data[station] = {}
        for var, dtype in acorn_constants.var_mapping_codar.iteritems():
            station_data[station][var] = np.array(np.full((lon_dim, lat_dim), np.nan, dtype=dtype))

        ds = Dataset(sourceVectorFile, mode='r')
        pos_array = np.array(ds.variables['POSITION'])
        pos_array = pos_array - 1
        for var, dtype in acorn_constants.var_mapping_codar.iteritems():
            if var in ds.variables:
                station_data[station][var] = acorn_utils.expand_array(
                    pos_array, ds.variables[var], array_size, dtype)
            else:
                logging.warning("Variable '%s' does not exist in NetCDF file" % var)

            # Arrays are flipped (going bottom to top), flip them over the V
            # axis
            station_data[station][var] = Util.adjust_grid(station_data[station][var], lon_dim, lat_dim)

            # Reshape to a grid
            station_data[station][var] = station_data[station][var].reshape(lon_dim, lat_dim)

        attribute_templating['siteAbstract'] = str(ds.getncattr('abstract'))
        attribute_templating['prevHistory'] = str(ds.getncattr('history'))
        attribute_templating['timeCoverageDuration'] = str(ds.getncattr('time_coverage_duration'))
        attribute_templating['id'] = str(ds.getncattr('id'))

        ds.close()

        acorn_utils.fill_global_attributes(F, site, timestamp, False, attribute_templating)

        # Build a QC matrix with zeros. The only QC check we will perform here
        # is the GDOP one
        station_data[station]["speed_qc"] = np.zeros((lon_dim, lat_dim), dtype=np.float32)

        # Eliminate points with bad GDOP (like in WERA)
        acorn_qc.gdop_masking(
            station_data,
            site_gdop,
            "speed_qc"
        )

        ucur = station_data[station]['ssr_Surface_Eastward_Sea_Water_Velocity']
        vcur = station_data[station]['ssr_Surface_Northward_Sea_Water_Velocity']

        ucur_sd = station_data[station]['ssr_Surface_Eastward_Sea_Water_Velocity_Standard_Error']
        vcur_sd = station_data[station]['ssr_Surface_Northward_Sea_Water_Velocity_Standard_Error']

        speed_qc_max = station_data[station]["speed_qc"]
        speed_qc_max[np.isnan(ucur)] = np.nan
        speed_qc_max[np.isnan(vcur)] = np.nan

        time_dimension = F.createDimension("TIME")
        latitude_dimension = F.createDimension("I", lat_dim)
        longitude_dimension = F.createDimension("J", lon_dim)

        # TODO chunking of variables
        netcdf_vars = {}
        for var in acorn_constants.variable_order:
            var_info = acorn_constants.current_variables[var]
            # Replace LATITUDE -> I, LONGITUDE -> J
            dims = var_info['dimensions']
            if "LATITUDE" in dims:
                dims[dims.index("LATITUDE")] = "I"

            if "LONGITUDE" in dims:
                dims[dims.index("LONGITUDE")] = "J"

            if var == "LATITUDE" or var == "LONGITUDE":
                dims = [ "I", "J" ]

            var_info['dimensions'] = dims

            netcdf_vars[var] = acorn_utils.add_netcdf_variable(F, var, var_info, attribute_templating)

        netcdf_vars["TIME"].setncattr("local_time_zone", site_description['timezone'])
        timestamp1950 = acorn_utils.days_since_1950(timestamp)

        netcdf_vars["TIME"][:] = [ timestamp1950 ]
        netcdf_vars["LATITUDE"][:] = acorn_utils.nan_to_fill_value(site_lats)
        netcdf_vars["LONGITUDE"][:] = acorn_utils.nan_to_fill_value(site_lons)

        netcdf_vars["GDOP"][:] = acorn_utils.nan_to_fill_value(site_gdop)

        netcdf_vars["UCUR"][0] = acorn_utils.nan_to_fill_value(ucur)
        netcdf_vars["VCUR"][0] = acorn_utils.nan_to_fill_value(vcur)

        netcdf_vars["UCUR_sd"][0] = acorn_utils.nan_to_fill_value(ucur_sd)
        netcdf_vars["VCUR_sd"][0] = acorn_utils.nan_to_fill_value(vcur_sd)

        # Find all non-nan and non-zero matrices in seasonde_LLUV_S[2-6]CN and
        # use it as NOBS2
        nobs_options = []
        for var_name in acorn_constants.CODAR_NOBS_VARIABLES:
            station_data[station][var_name]
            if not np.all(np.logical_or(np.isnan(station_data[station][var_name]), station_data[station][var_name]==0)):
                nobs_options.append(station_data[station][var_name])

        if len(nobs_options) < 2:
            logging.error("Not enough non-nan seasonde_LLUV_SXCN matrices found to build NOBS variable")
            exit(1)

        # Use first 2 non-nan NOBS matrices we have found
        for i in [0, 1]:
            nobs_variable = "NOBS%d" % (i+1)
            netcdf_vars[nobs_variable][0] = acorn_utils.nan_to_fill_value(
                nobs_options[i],
                acorn_constants.BYTE_FILL_VALUE). \
            reshape((lon_dim, lat_dim))

        # UCUR_quality_control and VCUR_quality_control are exactly the same
        netcdf_vars["UCUR_quality_control"][0] = netcdf_vars["VCUR_quality_control"][0] = \
            acorn_utils.nan_to_fill_value(speed_qc_max, acorn_constants.BYTE_FILL_VALUE).reshape((lon_dim, lat_dim))

def generate_current_from_vector_file(vectorFile, dest_dir):
    station = site = acorn_utils.get_station(vectorFile)
    timestamp = acorn_utils.get_timestamp(vectorFile)
    qc = acorn_utils.is_qc(vectorFile) # Always False, but maybe one day...

    return generate_current(site, timestamp, qc, dest_dir)

def generate_current(site, timestamp, qc, dest_dir):
    """
    Main function to build a current from a vector
    """

    dest_file = acorn_utils.generate_current_filename(site, timestamp, False)
    dest_file = os.path.join(dest_dir, dest_file)

    logging.info("Destination file: '%s'" % dest_file)

    vector_file_list = Util.get_vectors_for_site(site, timestamp)
    vector_file_list = Util.get_existing_vectors(vector_file_list)

    if Util.has_enough_vectors(vector_file_list):
        tmp_dir = tempfile.mkdtemp()

        vector_file_list = Util.prepare_vectors(tmp_dir, vector_file_list)

        F = Dataset(dest_file, mode='w')
        Util.transform_vector(F, site, timestamp, vector_file_list)
        F.close()

        shutil.rmtree(tmp_dir)
        logging.info("Wrote file '%s'" % dest_file)
        return acorn_utils.ACORNError.SUCCESS
    else:
        logging.error("Not enough vectors for file '%s'" % dest_file)
        return acorn_utils.ACORNError.NOT_ENOUGH_FILES
