import datetime
import re

import pandas as pd
import requests
from retrying import retry

from .common import *

logger = logging.getLogger(__name__)


def get_last_modification_date_resource_id(package_name, resource_id):
    """
    retrieves the last modification date of a specific resource_id belonging to a package_name
    :param package_name: str of the package_name
    :param resource_id: str of the resource_id
    :return: datetime
    """
    resources = retrieve_ls_package_resources(package_name)
    for r in resources:
        if r['id'] == resource_id:
            last_mod = r['last_modified']

            if last_mod is not None:
                last_mod.encode('latin-1')
                #  date formatting different between resources
                if len(last_mod) < 22:
                    last_modification = datetime.datetime.strptime(last_mod, '%Y-%m-%dT%H:%M:%S')
                else:
                    last_modification = datetime.datetime.strptime(last_mod, '%Y-%m-%dT%H:%M:%S.%f')

                return last_modification


def read_metadata_file():
    """
    reads the METADATA_FILE csv file as a panda dataframe
    :return: panda dataframe of METADATA_FILE
    """
    df = pd.read_csv(METADATA_FILE)
    df.set_index('package_name', inplace=True)
    return df


def package_metadata(package_name):
    """
    read the metadata for a package_name as stored in the METADATA_FILE csv
    :param package_name:
    :returns: panda dataframe of metadata
    """
    df = read_metadata_file()
    df['first_deployment_date'] = pd.to_datetime(df['first_deployment_date'], format='%d/%m/%Y')
    return df.loc[package_name]


def list_new_resources_to_dl(resources):
    """
    returns a list of resources to be downloaded based on the "last_modified" field from the web-service when the pickly
    of what has already been downloaded
    :param resources: dictionary of resources (previously got from retrieve_ls_package_resources function)
    :return: list of resource_ids to re-downloaded
    """
    list_ids = []

    for r in resources:
        last_mod = r['last_modified']
        description = r['description']
        # skip resource_id IF the description field contains the string 'metadata' and current
        if re.search("metadata", description) or re.search("current", description):
            continue

        if last_mod is not None:
            last_mod.encode('latin-1')
            #  date formatting different between resources
            if len(last_mod) < 22:
                last_modification = datetime.datetime.strptime(last_mod, '%Y-%m-%dT%H:%M:%S')
            else:
                last_modification = datetime.datetime.strptime(last_mod, '%Y-%m-%dT%H:%M:%S.%f')

            last_downloaded_date = get_last_downloaded_date_resource_id(r['id'])  # from pickle file

            if last_modification > last_downloaded_date:
                logger.info("Resource {id} from package {package} was updated on {last_modification}. "
                            "Last downloaded date was {last_downloaded_date}".format(
                    id=r['id'],
                    package=r['package_id'],
                    last_modification=last_modification,
                    last_downloaded_date=last_downloaded_date))
                list_ids.append(r['id'].encode('latin-1'))
            else:
                logger.info("Resource {id} from package {package} is already up to date".format(
                    id=r['id'],
                    package=r['package_id']))

        else:  # if modification date isn't available for resource_id, we re-download the file as a matter of precaution
            logger.info("Resource {id} from package {package} does not have a modification date".format(
                id=r['id'],
                package=r['package_id']))
            list_ids.append(r['id'].encode('latin-1'))

    return list_ids


def get_last_downloaded_date_resource_id(resource_id):
    """
    retrieves the datetime of the last downloaded date of a resource_id
    :param resource_id: str of the resource_id
    :return: datetime of the last downloaded date
    """
    pickle_file = os.path.join(WIP_DIR, 'last_downloaded_date_resource_id.pickle')
    last_downloaded_date_resource_id = load_pickle_db(pickle_file)

    if not last_downloaded_date_resource_id:
        return datetime.datetime(1970, 1, 1, 0, 0)  # if pickle file doesn't exist yet, creating epoch datetime
    else:
        if resource_id in list(last_downloaded_date_resource_id.keys()):
            return last_downloaded_date_resource_id[resource_id]  # if package_name has already been downloaded
        else:
            return datetime.datetime(1970, 1, 1, 0, 0)  # if new resource_id


def list_package_names():
    """
    list all package_names from csv METADATA_FILE file
    :return: package_name :list
    """
    df = read_metadata_file()
    return df.index.values.tolist()


def param_mapping_parser(filepath):
    """
    parser of mapping csv file
    :param filepath: path to csv file containing mapping information between QLD parameters and IMOS/CF parameters
    :return: pandas dataframe of parameter mapping
    """
    if not filepath:
        logger.error('No PARAMETER MAPPING file available')
        exit(1)

    df = pd.read_table(filepath, sep=r",",
                       engine='python')
    df.set_index('ORIGINAL_VARNAME', inplace=True)
    return df


@retry(stop_max_attempt_number=10)
def retrieve_ls_package_resources(package_name):
    """
    list all the resources in a package
    :param package_name: str of package name
    :returns: a list of resources for package_name
    """
    url = '%s%s' % (BASE_URL_METADATA, package_name)
    try:
        r = requests.get(url)
    except requests.exceptions.ConnectionError as err:
        logger.error('{url} service unavailable. {exception}. Retry'.format(url=url, exception=err))
        raise Exception

    res = r.json()
    # check if request successful
    assert res['success'] == True, 'Request to the url {url} failed'.format(url=url)

    num_resources_in_package = res['result']['num_resources']

    logger.info("Checking date last update of {resource} resources in package {name}.".format(
        resource=num_resources_in_package,
        name=package_name))

    return res['result']['resources']
