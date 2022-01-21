import os
import pickle
import logging

from .netcdf import nc_get_max_timestamp

LOGGER = logging.getLogger(__name__)


def pickle_get_latest_processed_date(pickle_path, source_id):
    """
    Returns the latest downloaded date successfully of a source_id by looking
    into the saved pickle file

        Parameters:
            source_id (string): source_id value

        Returns:
            date (datetime): date of latest processed data

    """
    if os.path.isfile(pickle_path):
        with open(pickle_path, 'rb') as p_read:
            previous_download = pickle.load(p_read)

            if source_id in previous_download.keys():
                return previous_download[source_id]['latest_downloaded_date']
            else:
                LOGGER.warning('{source_id}: first time data is downloaded'.format(source_id=source_id))
                return None
    else:
        LOGGER.warning('Pickle file does not exist yet')
        return None


def pickle_db_load(pickle_file_path):
    """
    load a saved pickle file

        Parameters:
            pickle_file_path (string): path of pickle file

        Returns:
            pickle data
    """
    if os.path.isfile(pickle_file_path):
        try:
            with open(pickle_file_path, 'rb') as p_read:
                return pickle.load(p_read)
        except Exception as err:
            return
    else:
        LOGGER.warning("file '{file}' does not exist".format(file=pickle_file_path))


def pickle_save_latest_download_success(pickle_file_path, source_id, nc_path):
    previous_download = pickle_db_load(pickle_file_path)
    if previous_download is None:
        previous_download = {source_id: {'latest_downloaded_date': nc_get_max_timestamp(nc_path)}}
    else:
        previous_download[source_id] = {'latest_downloaded_date': nc_get_max_timestamp(nc_path)}

    with open(pickle_file_path, 'wb') as p_write:
        pickle.dump(previous_download, p_write)

    LOGGER.info('{source_id}: Successfully saved latest_downloaded_date {latest_downloaded_date} to {pickle_file_path}'.format(
        source_id=source_id,
        latest_downloaded_date=nc_get_max_timestamp(nc_path),
        pickle_file_path=pickle_file_path
    ))