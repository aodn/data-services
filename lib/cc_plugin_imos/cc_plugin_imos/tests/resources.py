from pkg_resources import resource_filename
import tempfile
import os
import subprocess

def get_filename(path):
    '''
    Returns the path to a valid dataset, generating a netCDF file from
    the CDL of the same name when called.

    '''
    filename = resource_filename('cc_plugin_imos', path)
    cdl_path = filename.replace('.nc', '.cdl')
    if filename.endswith('.nc'):
        assert os.path.exists(cdl_path), 'Test source file %s does not exist!' % cdl_path
        temp_dir = tempfile.mkdtemp(prefix='nc_checker_imos_unittests_')
        filename = os.path.join(temp_dir, os.path.basename(filename))
        generate_dataset(cdl_path, filename)
    return filename

def generate_dataset(cdl_path, nc_path):
    subprocess.call(['ncgen', '-o', nc_path, cdl_path])


def static_files_testing():
    static_files = {
        'bad_data'      : get_filename('tests/data/imos_bad_data.nc'),
        'good_data'     : get_filename('tests/data/imos_good_data.nc'),
        'missing_data'  : get_filename('tests/data/imos_missing_data.nc'),
        'test_variable' : get_filename('tests/data/imos_test_variable.nc'),
        'data_var'      : get_filename('tests/data/imos_data_var.nc'),
        'bad_coords'    : get_filename('tests/data/imos_bad_coords.nc'),
        'new_data'      : get_filename('tests/data/imos_new_data.nc'),
        'srs_good_data' : get_filename('tests/data/srs_good_data.nc'),
        'srs_bad_data'  : get_filename('tests/data/srs_bad_data.nc'),
    }
    return static_files
