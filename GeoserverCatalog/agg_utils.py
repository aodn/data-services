import csv
from typing import Dict, List

import requests

MOORINGS_ADDRESS = "http://geoserver-123.aodn.org.au/geoserver/ows?typeName=moorings_all_map&SERVICE=WFS&REQUEST=GetFeature&VERSION=1.0.0&outputFormat=csv"
CONTENT_SPLIT = '\r\n'
KEY_SPLIT = ','
REMOVE_KEYS = ''


def get_geoserver_data(addr: str) -> str:
    req = requests.get(addr)
    content = req.content.decode('utf-8')
    return content.splitlines()


def process_geoserver_content(list_of_content: List[str]
                              ) -> [List[str], List[str]]:
    datalist = list(csv.reader(list_of_content, delimiter=KEY_SPLIT))
    return datalist[0], datalist[1:]


def geoserver_dict(keys: List[str], values: List[str],
                   mkey: str = 'url') -> Dict[str, str]:
    ind = keys.index(mkey)
    res = {}
    for items in values:
        key = items[ind]
        if key not in res.keys():
            res[key] = {}
        _extend_entry(res[key], keys, items, extend_type=list)
    return res


def _extend_entry(rdict: Dict[str, str],
                  keys: List[str],
                  items: List[str],
                  extend_type=list):
    """
    Extend :rdict: :keys: for each item in :items: if there is more than one entry for the same key. The type used is :extend_type:.
    """
    if len(keys) != len(items):
        raise ValueError("Length mismatch between keys and items arguments")

    for sind, subfield in enumerate(keys):
        if subfield in rdict.keys():
            if isinstance(rdict[subfield], extend_type):
                rdict[subfield] += [items[sind]]
            else:
                oldkey = rdict[subfield]
                rdict[subfield] = extend_type()
                rdict[subfield] += [oldkey]
        else:
            rdict[subfield] = items[sind]
    pass
