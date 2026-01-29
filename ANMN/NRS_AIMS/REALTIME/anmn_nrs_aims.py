#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Download ANMN NRS data from AIMS Web Service for Darwin, Yongala and Beagle
The script reads an XML file provided by AIMS and looks for channels with
new data to download. It compares this list with a pickle file (pythonic
way to store python variables) containing what has already been downloaded
in the previous run of this script.
Some modifications on the files have to be done so they comply with CF and
IMOS conventions.
The IOOS compliance checker is used to check if the first downloaded file of
a channel complies once modified. If not, the download of the rest of the
channel is aborted until some modification on the source code is done so
the channel can pass the checker.
Files which don't pass the checker will land in os.path.join(wip_path, 'errors')
for investigation. No need to reprocess them as they will be redownloaded on
next run until they end up passing the checker. Files in the 'errors' dir can be
removed at anytime

IMPORTANT:
is it essential to look at the logging os.path.join(wip_path, 'aims.log')
to know which channels have problems and why as most of the time, AIMS will
have to be contacted to sort out issues.


author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import argparse
import datetime
import logging
import os
import re
import shutil
import sys
import unittest as data_validation_test
from itertools import groupby
from pathlib import Path

from aims_realtime_util import (
    convert_time_cf_to_imos,
    create_list_of_dates_to_download,
    download_channel,
    fix_data_code_from_filename,
    fix_provider_code_from_filename,
    get_main_netcdf_var,
    has_var_only_fill_value,
    is_no_data_found,
    is_time_monotonic,
    is_time_var_empty,
    list_recursively_files_abs_path,
    logging_aims,
    md5,
    modify_aims_netcdf,
    parse_aims_xml,
    remove_dimension_from_netcdf,
    remove_end_date_from_filename,
    rm_tmp_dir,
    save_channel_info,
    set_up,
)
from dest_path import get_anmn_nrs_site_name
from netCDF4 import Dataset
from tendo import singleton
from util import pass_netcdf_checker

MD5_EXPECTED_VALUE = "a6207e053f1cc0e00d171701f0cdb186"

DATA_WIP_PATH = os.path.join(
    os.environ.get("WIP_DIR"),
    "ANMN",
    "NRS_AIMS_Darwin_Yongala_data_rss_download_temporary",
)
ANMN_NRS_INCOMING_DIR = os.path.join(
    os.environ.get("INCOMING_DIR"), "AODN", "ANMN_NRS_DAR_YON"
)
ANMN_NRS_ERROR_DIR = os.path.join(os.environ["ERROR_DIR"], "ANMN_NRS_DAR_YON")


def modify_anmn_nrs_netcdf(netcdf_file_path, channel_id_info):
    """
    Refines ANMN NRS specific metadata and coordinate variables.
    """
    # First pass: Generic AIMS modifications
    modify_aims_netcdf(netcdf_file_path, channel_id_info)

    site_map = {
        "Yongala": ("NRSYON", "Yongala NRS Buoy"),
        "Darwin": ("NRSDAR", "Darwin NRS Buoy"),
        "Beagle": ("DARBGF", "Beagle Gulf Mooring"),
    }

    site_name = channel_id_info.get("site_name", "")
    site_data = next((v for k, v in site_map.items() if k in site_name), None)

    if not site_data:
        return False  # Site not recognised

    with Dataset(netcdf_file_path, "a") as nc:
        nc.site_code, nc.platform_code = site_data
        nc.aims_channel_id = int(channel_id_info["channel_id"])

        if channel_id_info.get("metadata_uuid") != "Not Available":
            nc.metadata_uuid = channel_id_info["metadata_uuid"]

        # Depth Variable Attributes (Common configurations)
        depth_attrs = {
            "positive": "down",
            "axis": "Z",
            "reference_datum": "sea surface",
            "valid_min": -10.0,
            "valid_max": 30.0,
            "units": "m",
        }

        # Handle 'depth'
        if "depth" in nc.variables:
            var = nc.variables["depth"]
            for k, v in depth_attrs.items():
                setattr(var, k, v)
            var.long_name = "nominal depth"
            nc.renameVariable("depth", "NOMINAL_DEPTH")

        # Handle 'DEPTH' (actual depth)
        if "DEPTH" in nc.variables:
            var = nc.variables["DEPTH"]
            # Standard depth attributes plus coordinates
            for k, v in depth_attrs.items():
                setattr(var, k, v)
            var.long_name = "actual depth"
            var.coordinates = "TIME LATITUDE LONGITUDE NOMINAL_DEPTH"

    # Coordinate String Assignment
    # We close the file above so that the next functions see the changes
    main_var = get_main_netcdf_var(netcdf_file_path)

    with Dataset(netcdf_file_path, "a") as nc:
        if main_var in nc.variables:
            coords = "TIME LATITUDE LONGITUDE"
            if "NOMINAL_DEPTH" in nc.variables:
                coords += " NOMINAL_DEPTH"
            nc.variables[main_var].coordinates = coords

    # Final transformations
    if not convert_time_cf_to_imos(netcdf_file_path):
        return False

    # This MUST be last as it reshapes the file
    remove_dimension_from_netcdf(netcdf_file_path)

    return True


def move_to_tmp_incoming(netcdf_path):
    """
    Renames the NetCDF to include its MD5 hash, moves it to the manifest directory,
    and cleans up the now-empty source directory.
    """
    logger = logging.getLogger(__name__)

    source_file = Path(netcdf_path)
    source_dir = source_file.parent

    # Construct the new filename: [name_without_date].[md5].nc
    # remove_end_date_from_filename returns a string, so we wrap it in Path
    name_no_date = Path(remove_end_date_from_filename(str(source_file))).stem
    file_hash = md5(str(source_file))
    new_filename = f"{name_no_date}.{file_hash}.nc"

    destination = Path(TMP_MANIFEST_DIR) / new_filename

    try:
        # Apply permissions (664)
        source_file.chmod(0o664)

        # Perform the move
        shutil.move(str(source_file), str(destination))
        logger.info(f"Moved {source_file.name} to {destination}")

        # Cleanup: Delete the source directory if it is now empty
        try:
            source_dir.rmdir()
            logger.debug(f"Cleaned up empty directory: {source_dir}")
        except OSError:
            logger.debug(f"Source directory not empty; skipping cleanup: {source_dir}")

    except Exception as e:
        logger.error(f"Failed to move {source_file} to incoming: {e}")
        raise


def process_monthly_channel(channel_id, aims_xml_info, level_qc):
    """
    Downloads all the data available for one channel_id and moves the file to a wip_path dir

    aims_service : 1   -> FAIMMS data
                   100 -> SOOP TRV data
                   300 -> NRS DATA
    for monthly data download, only 1 and 300 should be use
    """
    contact_aims_msg = "Process of channel aborted - CONTACT AIMS"
    wip_path = Path(os.environ.get("data_wip_path", ""))

    logger.info(f"QC{level_qc} - Processing channel {channel_id}")

    channel_id_info = aims_xml_info[channel_id]
    from_date = channel_id_info["from_date"]
    thru_date = channel_id_info["thru_date"]

    # [start_dates, end_dates] generation
    start_dates, end_dates = create_list_of_dates_to_download(
        channel_id, level_qc, from_date, thru_date
    )

    if not start_dates:
        logger.info(f"QC{level_qc} - Channel {channel_id}: already up to date")
        return

    # download monthly file
    for start_dt, end_dt in zip(start_dates, end_dates):
        start_date = start_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        end_date = end_dt.strftime("%Y-%m-%dT%H:%M:%SZ")

        netcdf_tmp_file_path = download_channel(
            channel_id, start_date, end_date, level_qc
        )

        if netcdf_tmp_file_path is None:
            logger.error(
                f"   Channel {channel_id} - not valid zip file - {contact_aims_msg}"
            )
            break

        tmp_dir = Path(netcdf_tmp_file_path).parent

        # NO_DATA_FOUND file only means there is no data for the selected time period.
        # Could be some data afterwards
        if is_no_data_found(netcdf_tmp_file_path):
            logger.info(
                f"Channel {channel_id}: No data for the time period:[{start_date} - {end_date}]"
            )
            shutil.rmtree(tmp_dir)
            continue  # Move to next month

        # Start of validation sequence
        error_occurred = False

        if is_time_var_empty(netcdf_tmp_file_path):
            logger.error(
                f"Channel {channel_id}: No values in TIME variable - {contact_aims_msg}"
            )
            error_occurred = True

        elif not modify_anmn_nrs_netcdf(netcdf_tmp_file_path, channel_id_info):
            logger.error(
                f"Channel {channel_id}: Could not modify the NetCDF file - Process of channel aborted"
            )
            error_occurred = True

        else:
            main_var = get_main_netcdf_var(netcdf_tmp_file_path)
            if has_var_only_fill_value(netcdf_tmp_file_path, main_var):
                logger.error(
                    f"Channel {channel_id}: _Fillvalues only in main variable - {contact_aims_msg}"
                )
                error_occurred = True
            elif not get_anmn_nrs_site_name(netcdf_tmp_file_path):
                logger.error(
                    f"Channel {channel_id}: Unknown site_code gatt value - {contact_aims_msg}"
                )
                error_occurred = True
            elif not is_time_monotonic(netcdf_tmp_file_path):
                logger.error(
                    f"Channel {channel_id}: TIME value is not strictly monotonic - {contact_aims_msg}"
                )
                error_occurred = True

        if error_occurred:
            shutil.rmtree(tmp_dir)
            break

        # check every single file of the list. We don't assume that if one passes, all pass ... past proved this
        if not pass_netcdf_checker(netcdf_tmp_file_path, tests=["cf:1.6", "imos:1.3"]):
            logger.error(
                f"Channel {channel_id}: File does not pass CF/IMOS compliance checker - Process of channel aborted"
            )

            err_dest = wip_path / "errors" / os.path.basename(netcdf_tmp_file_path)
            shutil.copy(netcdf_tmp_file_path, err_dest)

            logger.error(f"File copied to {err_dest} for debugging")
            shutil.rmtree(tmp_dir)
            break

        netcdf_tmp_file_path = fix_data_code_from_filename(netcdf_tmp_file_path)
        netcdf_tmp_file_path = fix_provider_code_from_filename(
            netcdf_tmp_file_path, "IMOS_ANMN"
        )

        if not re.search(r"IMOS_ANMN_[A-Z]{1}_", netcdf_tmp_file_path):
            logger.error(
                f"   Channel {channel_id} - File name Data code does not pass REGEX - Process of channel aborted"
            )

            err_dest = wip_path / "errors" / os.path.basename(netcdf_tmp_file_path)
            shutil.copy(netcdf_tmp_file_path, err_dest)

            logger.error(f"   File copied to {err_dest} for debugging")
            shutil.rmtree(tmp_dir)
            break

        move_to_tmp_incoming(netcdf_tmp_file_path)

        # Update tracking
        save_channel_info(channel_id, aims_xml_info, level_qc, end_date)

        if TESTING:
            # The 2 next lines download the first month only for every single channel.
            # This is only used for testing
            # Note: save_channel_info already called above
            break


def process_qc_level(level_qc):
    """
    Downloads all channels for a specific QC level (0 or 1).
    """
    logger.info(
        f"Process ANMN NRS download from AIMS web service - QC level {level_qc}"
    )

    xml_url = (
        f"https://data.aims.gov.au/gbroosdata/services/rss/netcdf/level{level_qc}/300"
    )

    try:
        aims_xml_info = parse_aims_xml(xml_url)
    except Exception:
        # Use exc_info=True to automatically attach the stack trace to the log
        logger.critical(f"RSS feed not available at {xml_url}", exc_info=True)
        exit(1)

    # Iterate through channels
    for channel_id in aims_xml_info:
        try:
            process_monthly_channel(channel_id, aims_xml_info, level_qc)
        except Exception:
            # logger.exception automatically logs the error AND the traceback
            logger.exception(
                f"QC{level_qc} - Channel {channel_id}: Failed, unknown reason - manual debug required"
            )


class AimsDataValidationTest(data_validation_test.TestCase):
    def setUp(self):
        """Check that a the AIMS system or this script hasn't been modified.
        This function checks that a downloaded file still has the same md5.
        """
        channel_id = "84329"
        from_date = "2016-01-01T00:00:00Z"
        thru_date = "2016-01-02T00:00:00Z"
        level_qc = 1
        aims_rss_val = 300
        xml_url = (
            "https://data.aims.gov.au/gbroosdata/services/rss/netcdf/level%s/%s"
            % (str(level_qc), str(aims_rss_val))
        )

        logger.info("Data validation unittests...")
        aims_xml_info = parse_aims_xml(xml_url)
        channel_id_info = aims_xml_info[channel_id]
        self.nc_path = Path(
            download_channel(channel_id, from_date, thru_date, level_qc)
        )
        modify_anmn_nrs_netcdf(str(self.nc_path), channel_id_info)

        # force values of attributes which change all the time
        with Dataset(self.nc_path, "a") as nc:
            nc.date_created = "1970-01-01T00:00:00Z"
            nc.history = "data validation test only"
            # Check if NCO attribute exists before forcing it
            if hasattr(nc, "NCO"):
                nc.NCO = "NCO_VERSION"

    def tearDown(self):
        wip_dir = Path(os.environ.get("data_wip_path", "."))

        # Preserve the file for debugging before cleanup
        # self.md5_netcdf_value needs to be calculated in the test method itself
        if hasattr(self, "md5_netcdf_value"):
            debug_name = f"nc_unittest_{self.md5_netcdf_value}.nc"
            shutil.copy(self.nc_path, wip_dir / debug_name)

        # Cleanup: Remove the parent directory of the temp file
        if self.nc_path.parent.exists():
            shutil.rmtree(self.nc_path.parent)

    def test_aims_validation(self):
        if sys.version_info[0] < 3:
            self.md5_expected_value = "76c9a595264a8173545b6dc0c518a280"
        else:
            self.md5_expected_value = MD5_EXPECTED_VALUE
        self.md5_netcdf_value = md5(str(self.nc_path))

        self.assertEqual(self.md5_netcdf_value, self.md5_expected_value)


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-t",
        "--testing",
        action="store_true",
        help="testing only - downloads the first month of each channel",
    )

    return parser.parse_args()


if __name__ == "__main__":
    vargs = args()
    me = singleton.SingleInstance()
    os.environ["data_wip_path"] = os.path.join(
        os.environ.get("WIP_DIR"),
        "ANMN",
        "NRS_AIMS_Darwin_Yongala_data_rss_download_temporary",
    )
    global TMP_MANIFEST_DIR
    global TESTING

    set_up()

    # initialise logging
    logging_aims()
    global logger
    logger = logging.getLogger(__name__)

    # data validation test
    runner = data_validation_test.TextTestRunner()
    itersuite = data_validation_test.TestLoader().loadTestsFromTestCase(
        AimsDataValidationTest
    )
    res = runner.run(itersuite)

    if not DATA_WIP_PATH:
        logger.critical("environment variable data_wip_path is not defined.")
        exit(1)

    # script optional argument for testing only. used in process_monthly_channel
    TESTING = vargs.testing

    rm_tmp_dir(DATA_WIP_PATH)

    if len(os.listdir(ANMN_NRS_INCOMING_DIR)) >= 2:
        logger.critical("Operation aborted, too many files in INCOMING_DIR")
        exit(1)

    if len(os.listdir(ANMN_NRS_ERROR_DIR)) >= 2:
        logger.critical("Operation aborted, too many files in ERROR_DIR")
        exit(1)

    if not res.failures:
        for level in [0, 1]:
            date_str_now = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
            TMP_MANIFEST_DIR = os.path.join(
                DATA_WIP_PATH, "manifest_dir_tmp_{date}".format(date=date_str_now)
            )
            os.makedirs(TMP_MANIFEST_DIR)

            process_qc_level(level)

            lines_per_file = 2**12
            file_list = list_recursively_files_abs_path(TMP_MANIFEST_DIR)
            if len(file_list) > 0:
                for file_number, lines in groupby(
                    enumerate(file_list), key=lambda x: x[0] // lines_per_file
                ):
                    incoming_file = os.path.join(
                        DATA_WIP_PATH,
                        "anmn_nrs_aims_FV0{level}_{date}_{file_number}.manifest".format(
                            level=str(level), date=date_str_now, file_number=file_number
                        ),
                    )
                    with open(incoming_file, "w") as outfile:
                        for item in lines:
                            outfile.write("%s\n" % item[1])

                    os.chmod(incoming_file, 0o0664)  # change to 664 for pipeline v2
                    shutil.move(
                        incoming_file,
                        os.path.join(
                            ANMN_NRS_INCOMING_DIR, os.path.basename(incoming_file)
                        ),
                    )

    else:
        logger.error("Data validation unittests failed")
