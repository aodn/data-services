"""
common_waverider.py -> common functions not entirely specific to waverider data

 * load_pickle_db                     -> load data from a pickle file. We use it to know what has already been processed
 * retrieve_sites_info_waverider_kml  -> parse a kml file containing all the sites information and data url
 * placemark_info_folder              -> list all the info from a kml `folder`
 * download_site_data                 -> download the data as a zip file if never processed
 * param_mapping_parser               -> parameter mapping between AODN/CF vocab and data provider vocab
 * ls_txt_files                       -> list *.txt within directory
 * ls_ext_files                       -> list *.{ext} within directory
 * set_glob_attr                      -> set the global attributes of a NetCDF file
 * set_var_attr                       -> set the variable attributes of a variable in a NetCDF file

"""

import datetime
import logging
import os
import pickle
import re
import tempfile
import zipfile

import numpy as np
import pandas as pd
import requests
from BeautifulSoup import BeautifulSoup
from pykml import parser as kml_parser
from retrying import retry

from util import md5_file

logger = logging.getLogger(__name__)
WAVERIDER_KML_URL = 'https://s3-ap-southeast-2.amazonaws.com/transport.wa/WAVERIDER_DEPLOYMENTS/WaveStations.kml'
README_URL = 'https://s3-ap-southeast-2.amazonaws.com/transport.wa/WAVERIDER_DEPLOYMENTS/WAVE_READ_ME.htm'
NC_ATT_CONFIG = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
wip_dir_env = os.environ.get('WIP_DIR')
wip_dir_sub = os.path.join('AODN', 'DOT-WA-WAVE')
WIP_DIR = os.path.join(wip_dir_env, wip_dir_sub) if wip_dir_env is not None else os.path.join(tempfile.gettempdir(),
                                                                                              wip_dir_sub)
PICKLE_FILE = os.path.join(WIP_DIR, 'last_downloaded_waverider.pickle')


def load_pickle_db(pickle_file_path):
    """
    load a saved pickle file
    :param pickle_file_path:
    :returns: data from pickle file
    """
    if os.path.isfile(pickle_file_path):
        try:
            with open(pickle_file_path, 'rb') as p_read:
                return pickle.load(p_read)
        except:
            return
    else:
        logger.warning("file '{file}' does not exist".format(file=pickle_file_path))


def retry_if_urlerror_error(exception):
    """Return True if we should retry (in this case when it's an URLError), False otherwise"""
    return isinstance(exception, requests.ConnectionError)


@retry(retry_on_exception=retry_if_urlerror_error, stop_max_attempt_number=20)
def retrieve_sites_info_waverider_kml(kml_url=WAVERIDER_KML_URL):
    """
    downloads a kml from dept_of_transport WA. retrieve information to create a dictionary of site info(lat, lon, data url ...
    :param kml_url: string url kml to parse
    :return: dictionary
    """
    logger.info('Parsing {url}'.format(url=kml_url))
    try:
        fileobject = requests.get(kml_url).content
    except:
        logger.error('{url} not reachable. Retry'.format(url=kml_url))
        raise requests.ConnectionError

    root = kml_parser.fromstring(fileobject)

    # this kml has two 'sub-folders'. One for current, one for historical data.
    current_data = root.Document.Folder[0]
    historic_data = root.Document.Folder[1]

    current_site_info = placemark_info_folder(current_data)
    historic_site_info = placemark_info_folder(historic_data)

    # merging dicts
    sites_info = current_site_info.copy()
    sites_info.update(historic_site_info)

    return sites_info


def placemark_info_folder(kml_folder):
    """
    list information of all the placemarks for a folder within a kml file
    :param kml_folder: kml folder object from pykml
    :return: dictionary of site information
    """
    sites_info = dict()

    for pm in kml_folder.Placemark:
        logger.info('Retrieving information for {id} in kml'.format(id=pm.attrib['id']))

        # parsing information for each id/placemark
        coordinates = pm.Point.coordinates.pyval
        latitude = float(coordinates.split(',')[1])
        longitude = float(coordinates.split(',')[0])

        description = pm.description.text  # description contains URL's to download

        water_depth_regex = re.search('<b>Depth:</b>(.*)m<br>', description)
        if not water_depth_regex is None:
            water_depth = float(water_depth_regex.group(1).lstrip())
        else:
            water_depth = np.nan

        snippet = pm.snippet.pyval
        time_start = snippet.split(' - ')[0]
        time_end = snippet.split(' - ')[1]
        time_start = datetime.datetime.strptime(time_start, '%d/%m/%Y')
        time_end = datetime.datetime.strptime(time_end, '%d/%m/%Y')

        name = pm.name.text
        soup = BeautifulSoup(description)
        metadata_zip_url = soup.findAll('a', attrs={'href': re.compile("^http(s|)://.*_Metadata.zip")})[0].attrMap[
            'href']

        # some sites don't have any digital data to download. In that case, we skip the kml id
        yearly_processed_find = soup.findAll('a', attrs={'href': re.compile("^http(s|)://.*_YEARLY_PROCESSED.zip")})
        if len(yearly_processed_find) == 1:
            data_zip_url = yearly_processed_find[0].attrMap['href']
        elif len(yearly_processed_find) == 0:
            logger.warning('No digital data to download for kml id {id}'.format(id=pm.attrib['id']))
            continue

        site_code_regex = re.search('<b>Location ID:</b>(.*)<br>', description)
        site_code = site_code_regex.group(1).lstrip()

        site_info = {'site_name': name,
                     'lat_lon': [latitude, longitude],
                     'latitude': latitude,
                     'longitude': longitude,
                     'water_depth': water_depth,
                     'time_start': time_start,
                     'time_end': time_end,
                     'metadata_zip_url': metadata_zip_url,
                     'data_zip_url': data_zip_url,
                     'site_code': site_code}
        sites_info[pm.attrib['id']] = site_info

    return sites_info


@retry(retry_on_exception=retry_if_urlerror_error, stop_max_attempt_number=20)
def download_site_data(site_info):
    """
    download to a temporary directory the data
    :param site_info: a sub-dictionary of site information from retrieve_sites_info_waverider_kml function
    :return:
    """
    temp_dir = tempfile.mkdtemp()  # location of the downloaded data

    # download data file
    logger.info('downloading data for {site_code} to {temp_dir}'.format(site_code=site_info['site_code'],
                                                                        temp_dir=temp_dir))
    try:
        r = requests.get(site_info['data_zip_url'])
    except:
        logger.error('{url} not reachable. Retry'.format(url=site_info['data_zip_url']))
        raise requests.ConnectionError

    zip_file_path = os.path.join(temp_dir, os.path.basename(site_info['data_zip_url']))

    with open(zip_file_path, 'wb') as f:
        f.write(r.content)

    """
    If a site has already been successfully processed, and the data hasn't changed, the zip file will have the same md5 
    value as the one stored in the pickle file. We then store this in site_info['already_uptodate'] as a boolean to be 
    checked by the __main__ function running this script. In the case where the data file is the same, we don't bother
    unzipping it
    """
    md5_zip_file = md5_file(zip_file_path)
    site_info['zip_md5'] = md5_zip_file
    site_info['already_uptodate'] = False
    if os.path.exists(PICKLE_FILE):
        previous_download = load_pickle_db(PICKLE_FILE)
        if site_info['data_zip_url'] in previous_download.keys():
            if previous_download[site_info['data_zip_url']] == md5_zip_file:
                site_info['already_uptodate'] = True
                return temp_dir, site_info

    zip_ref = zipfile.ZipFile(zip_file_path, 'r')
    zip_ref.extractall(temp_dir)
    zip_ref.close()
    os.remove(zip_file_path)

    # download metadata file
    logger.info('downloading metadata for {site_code} to {temp_dir}'.format(site_code=site_info['site_code'],
                                                                            temp_dir=temp_dir))

    r = requests.get(site_info['metadata_zip_url'])
    zip_file_path = os.path.join(temp_dir, os.path.basename(site_info['metadata_zip_url']))

    with open(zip_file_path, 'wb') as f:
        f.write(r.content)

    zip_ref = zipfile.ZipFile(zip_file_path, 'r')
    zip_ref.extractall(temp_dir)
    zip_ref.close()
    os.remove(zip_file_path)

    return temp_dir, site_info


def param_mapping_parser(filepath):
    """
    parser of mapping csv file
    :param filepath: path to csv file containing mapping information between AWAC parameters and IMOS/CF parameters
    :return: pandas dataframe of filepath
    """
    if not filepath:
        logger.error('No PARAMETER MAPPING file available')
        exit(1)

    df = pd.read_table(filepath, sep=r",",
                       engine='python')
    df.set_index('ORIGINAL_VARNAME', inplace=True)
    return df


def ls_txt_files(path):
    """
    list text files from path
    :param path: path to find txt files extension in
    :return: list of txt files
    """
    return ls_ext_files(path, '.txt')


def ls_ext_files(path, extension):
    """
    list text files from path
    :param path: path to find txt files extension in
    :param extension: ".txt", ".csv" ...
    :return: list of files matching extension
    """
    file_ls = []
    for file in os.listdir(path):
        if file.endswith(extension):
            file_ls.append(os.path.join(path, file))

    return file_ls


def set_glob_attr(nc_file_obj, data, metadata):
    """
    Set generic global attributes in netcdf file object
    :param nc_file_obj: NetCDF4 object already opened
    :param data:
    :param metadata:
    :param deployment_code:
    :return:
    """
    setattr(nc_file_obj, 'data_collected_readme_url', README_URL)
    setattr(nc_file_obj, 'instrument_maker', metadata['INSTRUMENT MAKE'])
    setattr(nc_file_obj, 'instrument_model', metadata['INSTRUMENT MODEL'])
    setattr(nc_file_obj, 'deployment_code', metadata['DEPLOYMENT CODE'])
    setattr(nc_file_obj, 'site_code', metadata['SITE CODE'])
    setattr(nc_file_obj, 'site_name', metadata['SITE NAME'])
    setattr(nc_file_obj, 'waverider_type', metadata['DATA TYPE'])
    if isinstance(metadata['DEPTH'], str):
        setattr(nc_file_obj, 'water_depth', metadata['DEPTH'].strip('m'))
    setattr(nc_file_obj, 'geospatial_lat_min', metadata['LATITUDE'])
    setattr(nc_file_obj, 'geospatial_lat_max', metadata['LATITUDE'])
    setattr(nc_file_obj, 'geospatial_lon_min', metadata['LONGITUDE'])
    setattr(nc_file_obj, 'geospatial_lon_max', metadata['LONGITUDE'])
    setattr(nc_file_obj, 'time_coverage_start',
            data.datetime.dt.strftime('%Y-%m-%dT%H:%M:%SZ').values.min())
    setattr(nc_file_obj, 'time_coverage_end',
            data.datetime.dt.strftime('%Y-%m-%dT%H:%M:%SZ').values.max())
    setattr(nc_file_obj, 'date_created', pd.datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ"))
    setattr(nc_file_obj, 'local_time_zone', metadata['TIMEZONE'])


def set_var_attr(nc_file_obj, var_mapping, nc_varname, df_varname_mapped_equivalent, dtype):
    """
    set variable attributes of an already opened NetCDF file
    :param nc_file_obj:
    :param var_mapping:
    :param nc_varname:
    :param df_varname_mapped_equivalent:
    :param dtype:
    :return:
    """

    setattr(nc_file_obj[nc_varname], 'units', var_mapping.loc[df_varname_mapped_equivalent]['UNITS'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['LONG_NAME']):
        setattr(nc_file_obj[nc_varname], 'long_name', var_mapping.loc[df_varname_mapped_equivalent]['LONG_NAME'])
    else:
        setattr(nc_file_obj[nc_varname], 'long_name',
                var_mapping.loc[df_varname_mapped_equivalent]['STANDARD_NAME'].replace('_', ' '))

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['STANDARD_NAME']):
        setattr(nc_file_obj[nc_varname], 'standard_name', var_mapping.loc[df_varname_mapped_equivalent]['STANDARD_NAME'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['VALID_MIN']):
        setattr(nc_file_obj[nc_varname], 'valid_min', var_mapping.loc[df_varname_mapped_equivalent]['VALID_MIN'].astype(dtype))

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['VALID_MAX']):
        setattr(nc_file_obj[nc_varname], 'valid_max', var_mapping.loc[df_varname_mapped_equivalent]['VALID_MAX'].astype(dtype))

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['ANCILLARY_VARIABLES']):
        setattr(nc_file_obj[nc_varname], 'ancillary_variables',
                var_mapping.loc[df_varname_mapped_equivalent]['ANCILLARY_VARIABLES'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['REFERENCE_DATUM']):
        setattr(nc_file_obj[nc_varname], 'reference_datum',
                var_mapping.loc[df_varname_mapped_equivalent]['REFERENCE_DATUM'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['POSITIVE']):
        setattr(nc_file_obj[nc_varname], 'positive', var_mapping.loc[df_varname_mapped_equivalent]['POSITIVE'])
