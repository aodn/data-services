import logging
import os
import pickle
import shutil
import tempfile

logger = logging.getLogger(__name__)

BASE_URL_METADATA = 'https://data.qld.gov.au/api/action/package_show?id='
BASE_URL_DATA = 'https://data.qld.gov.au/api/3/action/datastore_search?resource_id='
METADATA_FILE = os.path.join(os.path.dirname(__file__), 'QLD_buoys_metadata.csv')
NC_ATT_CONFIG = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
QLD_WAVE_PARAMETER_MAPPING = os.path.join(os.path.dirname(__file__), 'qld_wave_parameter_mapping.csv')

wip_dir_env = os.environ.get('WIP_DIR')
wip_dir_sub = os.path.join('AODN', 'DES-QLD-WAVE-DM')
WIP_DIR = os.path.join(wip_dir_env, wip_dir_sub) if wip_dir_env is not None else os.path.join(tempfile.gettempdir(),
                                                                                              wip_dir_sub)
LIMIT_VALUES = '1000000'
FILLVALUE = -9999.9


def load_pickle_db(pickle_file_path):
    """
    load a saved pickle file
    :param pickle_file_path:
    :returns: data from pickle file
    """
    if os.path.isfile(pickle_file_path):
        with open(pickle_file_path, 'rb') as p_read:
            return pickle.load(p_read)
    else:
        logger.warning("file '{file}' does not exist".format(file=pickle_file_path))


def move_to_output_path(input_file, output_dir_path):
    """
    move input file to incoming directory with 664 permissions
    :param input_file:
    :param output_dir_path: path where input file should go to
    :return: None
    """
    if input_file is not None:
        os.chmod(input_file, 0o664)
        output_path = os.path.join(output_dir_path, os.path.basename(input_file))
        shutil.move(input_file, output_path)
        logger.info('NetCDF moved to {path}'.format(path=output_path))
