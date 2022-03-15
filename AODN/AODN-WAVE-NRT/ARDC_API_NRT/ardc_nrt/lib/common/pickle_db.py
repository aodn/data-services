import os
import pickle
import pandas
import logging

from .netcdf import nc_get_max_timestamp

LOGGER = logging.getLogger(__name__)


class ardcPickle(object):
    def __init__(self, output_path):
        self.output_path = output_path
        self.pickle_filepath = self.pickle_file_path()

    def pickle_file_path(self):
        return os.path.join(self.output_path, 'pickle.db')

    def load(self):
        """
        load a saved pickle file

            Parameters:
            Returns:
                pickle data
        """
        if os.path.isfile(self.pickle_filepath):
            try:
                with open(self.pickle_filepath, 'rb') as p_read:
                    return pickle.load(p_read)
            except Exception as err:
                return
        else:
            LOGGER.info("file '{file}' does not exist".format(file=self.pickle_filepath))

    def save(self, data):
        with open(self.pickle_filepath, 'wb') as p_write:
            pickle.dump(data, p_write)

    def get_latest_processed_date(self, source_id):
        """
        Returns the latest downloaded date successfully of a source_id by looking
        into the saved pickle file

            Parameters:
                source_id (string): source_id value

            Returns:
                date (pandas.Timestamp): timestamp of latest processed data
        """
        if os.path.isfile(self.pickle_filepath):
            with open(self.pickle_filepath, 'rb') as p_read:
                previous_download = pickle.load(p_read)

                if source_id in previous_download.keys():
                    return previous_download[source_id]['latest_downloaded_date']
                else:
                    LOGGER.info('{source_id}: first time data is downloaded'.format(source_id=source_id))
                    return None
        else:
            LOGGER.info('Pickle file does not exist yet')
            return None

    def save_latest_download_success(self, source_id, nc_path):
        """
        save in pickle file the max TIME value from a NetCDF as the latest_downloaded_date

             Parameters:
                source_id (string): source_id value

             Returns:
        """
        previous_download = self.load()
        if previous_download is None:
            previous_download = {source_id: {'latest_downloaded_date': nc_get_max_timestamp(nc_path)}}
        else:
            previous_download[source_id] = {'latest_downloaded_date': nc_get_max_timestamp(nc_path)}

        self.save(previous_download)

        LOGGER.info('{source_id}: Successfully saved latest_downloaded_date {latest_downloaded_date} to {pickle_file_path}'.format(
            source_id=source_id,
            latest_downloaded_date=nc_get_max_timestamp(nc_path),
            pickle_file_path=self.pickle_filepath
        ))

    def delete_source_id(self, source_id):
        previous_download = self.load()
        previous_download.pop(source_id, None)

        self.save(previous_download)

    def mod_source_id_latest_downloaded_date(self, source_id, timestamp):
        """
        works for new or existing source_id
        """
        if type(timestamp) != pandas._libs.tslibs.timestamps.Timestamp:
            raise ValueError("{timestamp} argument is not a pandas.Timestamp value. Abort".format(timestamp=timestamp))

        previous_download = self.load()
        previous_download[source_id] = {'latest_downloaded_date': timestamp}

        self.save(previous_download)
