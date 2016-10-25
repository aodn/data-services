from pkg_resources import resource_filename
import os
import subprocess

def get_filename(path):
    """
    Returns the path to a valid dataset
    """
    filename = resource_filename('cc_plugin_imos', path)
    if not os.path.exists(filename):
        cdl_path = filename.replace('.nc', '.cdl')
        generate_dataset(cdl_path, filename)
    return filename

def generate_dataset(cdl_path, nc_path):
    subprocess.call(['ncgen','-o', nc_path, cdl_path])

STATIC_FILES = {
    'bad_data'      : get_filename('tests/data/imos_bad_data.nc'),
    'good_data'     : get_filename('tests/data/imos_good_data.nc'),
    'missing_data'  : get_filename('tests/data/imos_missing_data.nc'),
    'test_variable' : get_filename('tests/data/imos_test_variable.nc'),
    'data_var'      : get_filename('tests/data/imos_data_var.nc'),
    'bad_coords'    : get_filename('tests/data/imos_bad_coords.nc'),
}
