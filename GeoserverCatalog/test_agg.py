import pytest

from agg_utils import (MOORINGS_ADDRESS, get_geoserver_data,
                       process_geoserver_content, geoserver_dict)


@pytest.mark.skip('slow')
def test_get_geoserver_data():
    content = get_geoserver_data(MOORINGS_ADDRESS)
    assert len(content) > 0


def test_process_geoserver():
    content = get_geoserver_data(MOORINGS_ADDRESS)
    keys, values = process_geoserver_content(content)
    assert len(keys) > 0
    assert len(values) > 0
    assert keys not in values
    assert len([True for value in values if value == keys]) == 0


def test_dict_by_url():
    content = get_geoserver_data(MOORINGS_ADDRESS)
    keys, values = process_geoserver_content(content)
    url_dict = geoserver_dict(keys, values, mkey='url')
    assert len(url_dict) > 0


def test_dict_by_sitecode():
    content = get_geoserver_data(MOORINGS_ADDRESS)
    keys, values = process_geoserver_content(content)
    sitecode_dict = geoserver_dict(keys, values, mkey='site_code')
    assert len(sitecode_dict) > 0
