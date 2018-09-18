#! /usr/bin/env python 
# -*- coding: utf-8 -*-
import csv
import datetime
import os
import pickle
import re
import shutil

import requests

from imos_logging import IMOSLogging

METADATA_FILE = os.path.join(os.path.dirname(__file__), 'QLD_buoys_metadata.csv')
INCOMING_DIR_WAVE = os.path.join(os.environ['INCOMING_DIR'], 'AODN/QLD-WAVE-NRT')
BASE_URL = 'https://data.qld.gov.au/api/action/package_show?id='


def get_package_info(package_names):
    """iterate through package list to check single resources last_modification date
    return: list of resource ID to upload"""
    list_resource_id = []
    for p in package_names:
        url = '%s%s' % (BASE_URL, p)
        try:
            r = requests.get(url)
        except requests.exceptions.ConnectionError as err:
            logger.error('Service unavailable. {exception}'.format(exception=err))

        res = r.json()
        # check if request successful
        assert res['success'] == True, 'Request to the url {url} failed'.format(url=url)

        num_resources_in_package = res['result']['num_resources']

        logger.info("Checking date last update of {resource} resources in package {name}.".format(
            resource=num_resources_in_package,
            name=p))

        resources = res['result']['resources']

        list = check_resource_last_update(resources, p)

        list_resource_id.extend(list)

    return list_resource_id


def check_resource_last_update(resources, package_name):
    """
    Cron runs once a week. Check that last change date
    if dataset has been modified since last CRON ran => (re)-harvest
    :returns list of ids to reharvest
    """
    list_ids = []

    for r in resources:
        last_mod = r['last_modified']
        description = r['description']
        # skip resource id of metadata
        if re.search("metadata", description):
            continue

        if last_mod is not None:

            last_mod.encode('latin-1')
            #  date formatting different between resources
            if len(last_mod) < 22:
                last_modification = datetime.datetime.strptime(last_mod, '%Y-%m-%dT%H:%M:%S')
            else:
                last_modification = datetime.datetime.strptime(last_mod, '%Y-%m-%dT%H:%M:%S.%f')

            last_downloaded_date = get_last_downloaded_date_package_name(package_name)

            if last_modification > last_downloaded_date:
                logger.info("Resource {id} from package {package} has been updated last {date} ago".format(
                    id=r['id'],
                    package=r['package_id'],
                    date=last_modification))
                list_ids.append(r['id'].encode('latin-1'))

                # save to pickle file the new last downloaded date for future run
                pickle_file = os.path.join(wip_dir, 'last_downloaded_date_package_name.pickle')
                last_downloaded_date_packages = load_pickle_db(pickle_file)
                if not last_downloaded_date_packages:
                    last_downloaded_date_packages = dict()

                last_downloaded_date_packages[package_name] = last_modification
                with open(pickle_file, 'wb') as p_write:
                    pickle.dump(last_downloaded_date_packages, p_write)

    return list_ids


def load_pickle_db(pickle_file_path):
    if os.path.isfile(pickle_file_path):
        with open(pickle_file_path, 'rb') as p_read:
            return pickle.load(p_read)


def get_last_downloaded_date_package_name(package_name):
    pickle_file = os.path.join(wip_dir, 'last_downloaded_date_package_name.pickle')
    last_downloaded_date_packages = load_pickle_db(pickle_file)

    if not last_downloaded_date_packages:
        return datetime.datetime.strptime("1970-01-01T00:00:00", '%Y-%m-%dT%H:%M:%S')  # if pickle file doesn't exist yet
    else:
        if package_name in last_downloaded_date_packages.keys():
            return last_downloaded_date_packages[package_name]  # if package_name has already been downloaded
        else:
            return datetime.datetime.strptime("1970-01-01T00:00:00", '%Y-%m-%dT%H:%M:%S')  # if new package_name


def read_package_name():
    """
    reads list of package name to check from csv METADATA_FILE file
    :returns package_name :list
    """
    package_name = []
    with open(METADATA_FILE, 'r') as metadata:
        met = csv.DictReader(metadata)
        for row in met:
            package_name.append(row['package_name'])

    return package_name


def create_manifest(manifest, list):
    with open(manifest, 'w') as manifest:
        for item in list:
            print item
            manifest.write("%s\n" % item)

    manifest.close()


def move_to_incoming(manifest_file):
    os.chmod(manifest_file, 0664)
    shutil.move(manifest_file, INCOMING_DIR_WAVE)


if __name__ == '__main__':
    """
    Read list of package name from METADATA_FILE
    Create manifest listing resources to upload from QLD CKAN API based on comparison of
    their last modification date and last downloaded date (stored in pickle file in
    os.path.join(wip_dir, 'last_downloaded_date_package_name.pickle')
    """
    global wip_dir
    wip_dir = os.path.join(os.environ['WIP_DIR'], 'AODN', 'WAVE-QLD-NRT')
    if not os.path.exists(wip_dir):
        os.makedirs(wip_dir)

    logging = IMOSLogging()
    global logger
    logger = logging.logging_start(os.path.join(wip_dir, 'process.log'))

    package_name = read_package_name()
    list_resource_id = get_package_info(package_name)

    if len(list_resource_id) != 0:
        logger.info('Creating manifest')
        manifest_file_path = os.path.join(wip_dir, 'list_resource_qld_wave_{date}.txt'.format(
            date=datetime.datetime.now().strftime('%Y%m%d%H%M%S')))

        create_manifest(manifest_file_path, list_resource_id)
        move_to_incoming(manifest_file_path)
