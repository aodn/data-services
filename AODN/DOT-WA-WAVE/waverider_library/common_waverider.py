import datetime
import logging
import os
import re
import tempfile
import zipfile
from urllib2 import Request, urlopen, URLError

import pandas as pd
import requests
from BeautifulSoup import BeautifulSoup
from dateutil import parser
from pykml import parser as kml_parser
from retrying import retry

logger = logging.getLogger(__name__)
WAVERIDER_KML_URL = 'https://s3-ap-southeast-2.amazonaws.com/transport.wa/WAVERIDER_DEPLOYMENTS/WaveStations.kml'
NC_ATT_CONFIG = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')


def retry_if_urlerror_error(exception):
    """Return True if we should retry (in this case when it's an URLError), False otherwise"""
    return isinstance(exception, URLError)


@retry(retry_on_exception=retry_if_urlerror_error, stop_max_attempt_number=20)
def retrieve_sites_info_waverider_kml(kml_url=WAVERIDER_KML_URL):
    """
    downloads a kml from dept_of_transport WA. retrieve informations to create a dictionary of site info(lat, lon, data url ...
    :param kml_url: string url kml to parse
    :return: dictionary
    """

    logger.info('Parsing {url}'.format(url=kml_url))
    try:
        request = Request(kml_url)
        fileobject = urlopen(request)
        #fileobject = requests.get(kml_url).text
    except:
        logger.error('{url} not reachable. Retry'.format(url=kml_url))
        raise URLError

    root = kml_parser.parse(fileobject).getroot()
    doc = root.Document.Folder

    sites_info = dict()
    for pm in doc.Placemark:
        logger.info('{id}'.format(id=pm.attrib['id']))  # missing heaps !
        coordinates = pm.Point.coordinates.pyval
        latitude = float(coordinates.split(',')[1])
        longitude = float(coordinates.split(',')[0])
        # water_depth = float(coordinates.split(',')[2])  # water depth is not in coordinates for this KML file

        description = pm.description.text

        water_depth_regex = re.search('<b>Depth:</b>(.*)m<br>', description)
        water_depth = water_depth_regex.group(1).lstrip()

        snippet = pm.snippet.pyval
        time_start = snippet.split(' - ')[0]
        time_end = snippet.split(' - ')[1]
        time_start = datetime.datetime.strptime(time_start, '%d/%m/%Y')
        time_end = datetime.datetime.strptime(time_end, '%d/%m/%Y')

        name = pm.name.text
        soup = BeautifulSoup(description)
        metadata_zip_url = soup.findAll('a', attrs={'href': re.compile("^http(s|)://.*_Metadata.zip")})[0].attrMap['href']
        data_zip_url = soup.findAll('a', attrs={'href': re.compile("^http(s|)://.*_YEARLY_PROCESSED.zip")})[0].attrMap[
            'href']

        site_code_regex = re.search('<b>Location ID:</b>(.*)<br>', description)
        site_code = site_code_regex.group(1).lstrip()

        site_info = {'site_name': name,
                     'lat_lon': [latitude, longitude],
                     'timezone': 8,
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


def download_site_data(site_info):
    """
    download to a temporary directory the data
    :param site_info: a sub-dictionary of site information from retrieve_sites_info_waverider_kml function
    :return:
    """
    temp_dir = tempfile.mkdtemp()

    # download data file
    logger.info('downloading data for {site_code} to {temp_dir}'.format(site_code=site_info['site_code'],
                                                                        temp_dir=temp_dir))

    r = requests.get(site_info['data_zip_url'])
    zip_file_path = os.path.join(temp_dir, os.path.basename(site_info['data_zip_url']))

    with open(zip_file_path, 'wb') as f:
        f.write(r.content)

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

    return os.path.join(temp_dir)


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


def set_glob_attr(nc_file_obj, data, metadata, deployment_code):
    """
    Set generic global attributes in netcdf file object
    :param nc_file_obj: NetCDF4 object already opened
    :param data:
    :param metadata:
    :param deployment_code:
    :return:
    """

    setattr(nc_file_obj, 'instrument_maker', metadata['INSTRUMENT MAKE'])
    setattr(nc_file_obj, 'instrument_model', metadata['INSTRUMENT MODEL'])
    setattr(nc_file_obj, 'deployment_code', deployment_code)
    setattr(nc_file_obj, 'site_code', metadata['SITE_CODE'])
    setattr(nc_file_obj, 'site_name', metadata['SITE_NAME'])
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
