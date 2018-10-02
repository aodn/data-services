AWAC_KML_URL = 'https://s3-ap-southeast-2.amazonaws.com/transport.wa/DOT_OCEANOGRAPHIC_SERVICES/AWAC_V2/AWAC.kml'

from urllib2 import Request, urlopen, URLError
from retrying import retry
from pykml import parser
import urllib2
import os

import datetime
from BeautifulSoup import BeautifulSoup
import re

#logger = logging.getLogger(__name__)

def retry_if_urlerror_error(exception):
    """Return True if we should retry (in this case when it's an URLError), False otherwise"""
    return isinstance(exception, URLError)

@retry(retry_on_exception=retry_if_urlerror_error, stop_max_attempt_number=10)
def retrieve_sites_info_kml(kml_url):
    """
    downloads a kml from dept_of_transport WA. retrieve informations to create a dictionary of site info(lat, lon, data url ...
    :param kml_url: string url kml to parse
    :return: dictionary
    """

    #logger.info('Parsing {url}'.format(url=kml_url))
    try:
        request = Request(kml_url)
        fileobject = urlopen(request)
    except:
        #logger.error('{url} not reachable. Retry'.format(url=data_url))
        raise URLError

    root = parser.parse(fileobject).getroot()
    doc = root.Document.Folder

    sites_info = dict()
    for pm in doc.Placemark:
        coordinates = pm.Point.coordinates.pyval
        latitude = float(coordinates.split(',')[1])
        longitude = float(coordinates.split(',')[0])
        water_depth = float(coordinates.split(',')[2])

        description = pm.description.text

        snippet = pm.snippet.pyval
        time_start = snippet.split(' - ')[0]
        time_end = snippet.split(' - ')[1]
        time_start = datetime.datetime.strptime(time_start, '%Y-%m-%d')
        time_end = datetime.datetime.strptime(time_end, '%Y-%m-%d')

        name = pm.name.text
        soup = BeautifulSoup(description)
        text_zip_url = soup.findAll('a', attrs={'href': re.compile("^http(s|)://.*_Text.zip")})[0].attrMap['href']

        m = re.search('<b>AWAC LOCATION ID:</b>(.*)<br>', description)
        site_code = m.group(1).lstrip()

        site_info = {'site_name': name,
                     'latitude': latitude,
                     'longitude': longitude,
                     'water_depth': water_depth,
                     'time_start': time_start,
                     'time_end': time_end,
                     'text_zip_url': text_zip_url}
        sites_info[site_code] = site_info

    return sites_info

sites_info = retrieve_sites_info_kml(AWAC_KML_URL)
