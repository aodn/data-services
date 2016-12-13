#!/usr/bin/env python
# -*- coding: utf-8 -*-
import logging
import os
import re
import smtplib
import xml.etree.ElementTree as ET

import click
import requests
from requests.packages.urllib3.exceptions import (InsecurePlatformWarning,
                                                  InsecureRequestWarning,
                                                  SNIMissingWarning)

# Logging configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()
logging.getLogger("requests").setLevel(logging.ERROR)

URL_REGEX = r"""(?i)\b((?:https?:(?:/{1,3}|[a-z0-9%])|[a-z0-9.\-]+[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)/)(?:[^\s()<>{}\[\]]+|\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\))+(?:\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’])|(?:(?<!@)[a-z0-9]+(?:[.\-][a-z0-9]+)*[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)\b/?(?!@)))"""
SEARCH_URL_SUFFIX = '/srv/eng/xml.search?buildSummary=false'
METADATA_URL_SUFFIX = '/srv/eng/xml.metadata.get?uuid='
DEFAULT_FILTER = 'mcp:MD_Metadata'

all_metadata = set()
broken_metadata = set()

all_broken_links = set()
all_tested_links = set()


class Metadata(object):
    def __init__(self, uuid, url, links):
        self.uuid = uuid
        self.url = url
        self.links = links
        self.broken_links = None


def send_email(email_from, email_to, subject, message, mail_server):
    msg = '''
        From: {email_from}
        To: {email_to}
        Subject: {subject}
        {message}

    '''

    msg = msg.format(email_from=email_from, email_to=email_to, subject=subject, message=message)
    # The actual mail send
    server = smtplib.SMTP(mail_server)
    server.starttls()
    server.mail(email_from)
    server.rcpt(email_to)
    server.data(msg)
    server.quit()


def link_checker(urls, validate_cert):
    broken_urls = list()

    for url in urls:
        if not (url.startswith('http://') or url.startswith('https://')):
            continue
        link_check(broken_urls, url, validate_cert)
    return broken_urls


def link_check(broken_urls, url, validate_cert, head_request=True):
    logger.info("Checking link {0}".format(url))
    try:
        if head_request:
            response = requests.head(url, verify=validate_cert, allow_redirects=True)
        else:
            response = requests.get(url, verify=validate_cert, allow_redirects=True)

        if response.status_code == 405:  # Method not allowed
            logger.info("Handling 405 Response for {0}".format(url))
            link_check(broken_urls, url, validate_cert, False)
        elif response.status_code >= 400:
            broken_urls.append(url)
            logger.error("Broken link {0} {1}".format(url, response))
    except requests.RequestException as e:
        broken_urls.append(url)
        logger.error("Broken link {0}".format(url))
        logger.error("Error: {0}".format(e))


def prepare_output_message():
    text = list()
    text.append('')
    text.append("Metadata tested: {0}".format(len(all_metadata)))
    text.append("Metadata with broken urls: {0}".format(len(broken_metadata)))
    text.append("Total tested links: {0}".format(len(all_tested_links)))
    text.append("Total broken links: {0}".format(len(all_broken_links)))

    for metadata_entry in broken_metadata:
        text.append('')
        text.append("Metadata UUID: {0}".format(metadata_entry.uuid))
        text.append("Metadata URL: {0}".format(metadata_entry.url))
        text.append("Broken Links: {0}".format(len(metadata_entry.broken_links)))
        text.append('')
        text.extend(list(set(all_broken_links).intersection(metadata_entry.broken_links)))
        text.append('')

    return os.linesep.join(text)


def broken_link_handler(geonetwork_url, validate_cert, filter_tag):
    search_url = geonetwork_url + SEARCH_URL_SUFFIX
    search_result = requests.post(search_url).text
    root = ET.fromstring(search_result)

    for metadata_xml_entry in root.iter('metadata'):
        metadata_info = list(metadata_xml_entry)[1]
        uuid = metadata_info.find('uuid').text
        metadata_url = "{0}{1}{2}".format(geonetwork_url, METADATA_URL_SUFFIX, uuid)
        metadata_result = requests.post(metadata_url).text
        if filter_tag != DEFAULT_FILTER:
            metadata_filter_result = metadata_result[
                                     metadata_result.index(filter_tag):metadata_result.rindex(filter_tag)]
            urls = re.findall(URL_REGEX, metadata_filter_result)
        else:
            urls = re.findall(URL_REGEX, metadata_result)

        metadata = Metadata(uuid, metadata_url, urls)
        all_metadata.add(metadata)

    logger.info('Starting broken links check')
    for metadata_entry in all_metadata:
        logger.info("{0} Testing metadata {1} {2}".format('-' * 32, metadata_entry.url, '-' * 32))
        # All links in metadata
        metadata_entry_links = set(metadata_entry.links)
        # Remove already tested links which will include broken links
        metadata_entry_test_links = metadata_entry_links.difference(all_tested_links)
        # Check links
        metadata_entry_broken_links = link_checker(metadata_entry_test_links, validate_cert)
        if len(metadata_entry_broken_links):
            all_broken_links.update(metadata_entry_broken_links)

        metadata_entry.broken_links = list(metadata_entry_links.intersection(all_broken_links))
        if len(metadata_entry.broken_links):
            broken_metadata.add(metadata_entry)

        all_tested_links.update(metadata_entry_test_links)

    logger.info('Finished broken links check')
    return broken_metadata


CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])


@click.command(context_settings=CONTEXT_SETTINGS)
@click.option('--geonetwork-url', required=True,
              help='Geonetwork URL. Example: http://catalogue-systest.aodn.org.au/geonetwork')
@click.option('--output-file', help='File name for output.')
@click.option('--email-to', help='Email the results to.')
@click.option('--email-from', default='developers@emii.org.au', help='Email the results from.')
@click.option('--mail-server', default='postoffice.sandybay.utas.edu.au:25',
              help='Mail Server to send emails. Example: postoffice.sandybay.utas.edu.au:25')
@click.option('--validate-cert', default=False, help='Validate SSL Certificate.')
@click.option('--filter-tag', help='Validate links within metadata tag only. Example: gmd:distributionInfo',
              default=DEFAULT_FILTER)
def execute(geonetwork_url, output_file, email_to, email_from, mail_server, validate_cert, filter_tag):
    """Find broken links in geonetwork metadata."""
    if not output_file and not email_to:
        click.echo('Error: Add option --email-to or --output-file')
        ctx = click.get_current_context()
        ctx.exit(1)

    if not validate_cert:
        # Disabling SSL warnings
        requests.packages.urllib3.disable_warnings(SNIMissingWarning)
        requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
        requests.packages.urllib3.disable_warnings(InsecurePlatformWarning)

    broken_link_handler(geonetwork_url, validate_cert, filter_tag)
    message = prepare_output_message()

    if output_file:
        with file(output_file, 'w') as f:
            f.write(message)

    if email_to:
        send_email(email_from, email_to, 'Geonetwork Metadata invalid urls Report', message, mail_server)


if __name__ == '__main__':
    execute()
