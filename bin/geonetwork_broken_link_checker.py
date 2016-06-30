# -*- coding: utf-8 -*-

import requests
import xml.etree.ElementTree as ET
import re
import logging
import sys
import io
import smtplib
import click

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('')

URL_REGEX = r"""(?i)\b((?:https?:(?:/{1,3}|[a-z0-9%])|[a-z0-9.\-]+[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)/)(?:[^\s()<>{}\[\]]+|\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\))+(?:\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’])|(?:(?<!@)[a-z0-9]+(?:[.\-][a-z0-9]+)*[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)\b/?(?!@)))"""
SEARCH_URL_SUFFIX = "/srv/eng/xml.search?buildSummary=false"
METADATA_URL_SUFFIX = "/srv/eng/xml.metadata.get?uuid="

metadatas = set()
broken_metadatas = set()

all_broken_links = set()
all_tested_links = set()


class Metadata:
    def __init__(self, uuid, url, links):
        self.uuid = uuid
        self.url = url
        self.links = links

    def add_broken_links(self, broken_links):
        self.broken_links = broken_links


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
        try:
            added_http_suffix = False
            if not (url.startswith("http://") or url.startswith("https://")):
                url = "http://" + url
                added_http_suffix = True

            logger.info('Checking link ' + url)
            request = requests.get(url, data={}, headers={})
            if request.status_code != 200:
                if added_http_suffix == True:
                    url = url.replace("http://", "")
                broken_urls.append(url)
                logger.error('Broken link ' + url)
        except:
            if added_http_suffix == True:
                url = url.replace("http://", "")
            broken_urls.append(url)
            logger.error('Broken link ' + url)
            logger.error("Unexpected error:", sys.exc_info()[0])

    return broken_urls


def prepare_output_message():
    text = []
    text.append('\n')
    text.append('\n')
    text.append("Metadata tested: " + str(len(metadatas)) + '\n')
    text.append("Metadata with broken urls: " + str(len(broken_metadatas)) + '\n')
    text.append("Total tested links: " + str(len(all_tested_links)) + '\n')
    text.append("Total broken links: " + str(len(all_broken_links)) + '\n')

    for metadata_entry in broken_metadatas:
        text.append('\n')
        text.append("Metadata UUID: " + metadata_entry.uuid + '\n')
        text.append("Metadata URL: " + metadata_entry.url + '\n')
        text.append("Broken Links: " + str(len(metadata_entry.broken_links)) + '\n')
        text.append('\n')

        for link in metadata_entry.broken_links:
            text.append(link + '\n')

        text.append('\n')

    return ''.join(text)


def broken_link_handler(geonetwork_url):
    search_url = geonetwork_url + SEARCH_URL_SUFFIX
    searchResult = requests.post(search_url).text
    root = ET.fromstring(searchResult)

    for metadata_xml_entry in root.iter('metadata'):
        metadata_info = list(metadata_xml_entry).__getitem__(1)
        uuid = metadata_info.find('uuid').text
        metadata_url = geonetwork_url + METADATA_URL_SUFFIX + uuid
        metadata_result = requests.post(metadata_url).text
        urls = re.findall(URL_REGEX, metadata_result)

        metadata = Metadata(uuid, metadata_url, urls)
        metadatas.add(metadata)

    logger.info("Starting broken links check")
    # count = 0  # Enable to test one metadata

    for metadata_entry in metadatas:
        # if (count == 1):  # Enable to test one metadata
        # break  # Enable to test one metadata
        logger.info(
            '----------------------------------Testing metadata ' + metadata_entry.url + "----------------------------------")
        # All links in metadata
        links = set(metadata_entry.links)

        # Remove already tested links which will include broken links
        test_links = links - all_tested_links

        broken_links = link_checker(test_links)
        if len(broken_links) > 0:
            metadata_entry.add_broken_links(broken_links)
            broken_metadatas.add(metadata_entry)
            all_broken_links.update(broken_links)

        all_tested_links.update(test_links)
        count = count + 1

    logger.info("Finished broken links check")
    return broken_metadatas


@click.command()
@click.option('--geonetwork_url',
              help='Geonetwork URL. Example: http://catalogue-systest.aodn.org.au/geonetwork', required=True)
@click.option('--file', help='File name for output.')
@click.option('--email_to', help='Email the results to.')
@click.option('--email_from', default='bruce.wayne@utas.edu.au', help='Email the results from.')
@click.option('--mail_server', default='postoffice.sandybay.utas.edu.au:25', help='Mail Server to send emails. Example: postoffice.sandybay.utas.edu.au:25')

def execute(geonetwork_url, file, email_to, email_from, mail_server):
    """Find broken links in geonetwork metadatas."""
    if (not file) and (not email_to):
        click.echo('Error: Add option --email_to or --file')
        return

    if (geonetwork_url):
        broken_link_handler(geonetwork_url)
        message = prepare_output_message()

        if (file):
            with io.FileIO(file, "w") as file:
                file.write(message)

        if (email_to):
            send_email(email_from, email_to, "Geonetwork Metadata invalid urls Report", message, mail_server)


if __name__ == '__main__':
    execute()
