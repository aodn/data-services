# -*- coding: utf-8 -*-

import logging
import os
import re
import smtplib
import sys
import xml.etree.ElementTree as ET

import click
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

URL_REGEX = r"""(?i)\b((?:https?:(?:/{1,3}|[a-z0-9%])|[a-z0-9.\-]+[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)/)(?:[^\s()<>{}\[\]]+|\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\))+(?:\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’])|(?:(?<!@)[a-z0-9]+(?:[.\-][a-z0-9]+)*[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)\b/?(?!@)))"""
SEARCH_URL_SUFFIX = '/srv/eng/xml.search?buildSummary=false'
METADATA_URL_SUFFIX = '/srv/eng/xml.metadata.get?uuid='

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


def link_checker(urls):
    broken_urls = list()

    for url in urls:
        added_http_suffix = False
        if not (url.startswith('http://') or url.startswith('https://')):
            url = "http://{0}".format(url)
            added_http_suffix = True
        logger.info("Checking link {0}".format(url))
        try:
            request = requests.get(url, data={}, headers={})
            if request.status_code != 200:
                if added_http_suffix:
                    url = url.replace('http://', '')
                broken_urls.append(url)
                logger.error("Broken link {0}".format(url))
        except:
            if added_http_suffix:
                url = url.replace('http://', '')
            broken_urls.append(url)
            logger.error("Broken link {0}".format(url))
            logger.error("Unexpected error: {0}".format(sys.exc_info()[0]))

    return broken_urls


def prepare_output_message():
    text = list()
    text.append("Metadata tested: {0}".format(len(all_metadata)))
    text.append("Metadata with broken urls: {0}".format(len(broken_metadata)))
    text.append("Total tested links: {0}".format(len(all_tested_links)))
    text.append("Total broken links: {0}".format(len(all_broken_links)))

    for metadata_entry in broken_metadata:
        text.append(None)
        text.append("Metadata UUID: {0}".format(metadata_entry.uuid))
        text.append("Metadata URL: {0}".format(metadata_entry.url))
        text.append("Broken Links: {0}".format(len(metadata_entry.broken_links)))
        text.append(None)

    text.extend(all_broken_links)
    text.append(None)

    return os.linesep.join(text)


def broken_link_handler(geonetwork_url):
    search_url = geonetwork_url + SEARCH_URL_SUFFIX
    search_result = requests.post(search_url).text
    root = ET.fromstring(search_result)

    for metadata_xml_entry in root.iter('metadata'):
        metadata_info = list(metadata_xml_entry)[1]
        uuid = metadata_info.find('uuid').text
        metadata_url = "{0}{1}{2}".format(geonetwork_url, METADATA_URL_SUFFIX, uuid)
        metadata_result = requests.post(metadata_url).text
        urls = re.findall(URL_REGEX, metadata_result)

        metadata = Metadata(uuid, metadata_url, urls)
        all_metadata.add(metadata)

    logger.info('Starting broken links check')
    # count = 0  # Enable to test one metadata

    count = 0
    for metadata_entry in all_metadata:
        # if (count == 1):  # Enable to test one metadata
        # break  # Enable to test one metadata
        logger.info("{0} Testing metadata {1} {2}".format('-'*32, metadata_entry.url, '-'*32))
        # All links in metadata
        links = set(metadata_entry.links)

        # Remove already tested links which will include broken links
        test_links = links.difference(all_tested_links)

        broken_links = link_checker(test_links)
        if len(broken_links):
            metadata_entry.broken_links = broken_links
            broken_metadata.add(metadata_entry)
            all_broken_links.update(broken_links)

        all_tested_links.update(test_links)
        count += 1

    logger.info('Finished broken links check')
    return broken_metadata


@click.command()
@click.option('--geonetwork-url', required=True,
              help='Geonetwork URL. Example: http://catalogue-systest.aodn.org.au/geonetwork')
@click.option('--output-file', help='File name for output.')
@click.option('--email-to', help='Email the results to.')
@click.option('--email-from', default='developers@emii.org.au', help='Email the results from.')
@click.option('--mail-server', default='postoffice.sandybay.utas.edu.au:25',
              help='Mail Server to send emails. Example: postoffice.sandybay.utas.edu.au:25')
def execute(geonetwork_url, output_file, email_to, email_from, mail_server):
    """Find broken links in geonetwork metadata."""

    broken_link_handler(geonetwork_url)
    message = prepare_output_message()

    if output_file:
        with file(output_file, 'w') as f:
            f.write(message)

    if email_to:
        send_email(email_from, email_to, 'Geonetwork Metadata invalid urls Report', message, mail_server)


if __name__ == '__main__':
    execute()
