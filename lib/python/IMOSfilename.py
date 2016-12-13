#! /usr/bin/env python
#
# Python module to parse, check and create filenames according to the
# IMOS convention.


import re
from datetime import datetime

#### DATA ###################################################################

# List of valid facility/sub-facility codes.
subFacilities = ('ANMN-NRS', 
                 'ANMN-NSW', 
                 'ANMN-QLD', 
                 'ANMN-SA', 
                 'ANMN-WA', 
                 'ANMN-PA', 
                 'ANMN-AM',
                 'ABOS-ASFS',
                 'ABOS-SOTS',
                 'ABOS-DA')

dataCodeLetters = 'ABCEFGIKMOPRSTUVWZ'


#### FUNCTIONS ##############################################################

def parseTime(tStr, strict=False):
    """
    Parse a date/time string within the filename and return it as a
    datetime object, or None if the the string doesn't match a known
    format.

    parseTime can handle strings several date/time formats, as long as
    time is either not included, or has exactly 6 digits.

    If strict is set to True, only time strings matching the full
    standard format (YYYYMMDDThhmmssZ) will be parsed.
    """

    ts = tStr.translate(None, 'TZ')   # remove 'T' and 'Z' from string

    # Try to work out what date/time format is used, assuming time, if
    # given, is always 6 digits
    if strict:
        if len(tStr) != 16: return None
        ts = tStr
        tFormat = '%Y%m%dT%H%M%SZ'
    elif len(ts) == 6:
        # YYMMDD date
        tFormat = '%y%m%d'
    elif len(ts) == 8:
        # YYYYMMDD date
        tFormat = '%Y%m%d'
    elif len(ts) == 12:
        # YYMMDD date + time
        tFormat = '%y%m%d%H%M%S'           
    elif len(ts) == 14:
        # YYYYMMDD date + time (this should be the norm)
        tFormat = '%Y%m%d%H%M%S'

    # now try to convert the string
    try:
        return datetime.strptime(ts, tFormat)
    except:
        return None


def parseDatasetPart(fld, info, errors):
    "Try to parse the optional PARTn field in a filename."
    if not fld.find('PART') == 0:
        return None
    try:
        info['dataset_part'] = int(fld[4:])
    except:
        errors.append('Invalid dataset part label "'+fld+'".')
    return info['dataset_part']


def parseEndTime(fld, info, errors):
    "Try to parse the dataset end time field in a filename."
    if not fld.find('END-') == 0:
        return None
    # require full date/time strings for netCDF files
    dt = parseTime(fld[4:], strict=(info['extension']=='nc'))
    if dt:
        info['end_time'] = dt
    else:
        errors.append('Invalid end time "'+fld+'".')
    return info['end_time']


def parseCreationTime(fld, info, errors):
    "Try to parse the creation time field in a filename."
    if not fld.find('C-') == 0:
        return None
    # require full date/time strings for netCDF files
    dt = parseTime(fld[2:], strict=(info['extension']=='nc'))
    if dt:
        info['creation_time'] = dt
    else:
        errors.append('Invalid creation time "'+fld+'".')
    return info['creation_time']


def parseProductCode(fld, info, errors):
    "Accept fld as the product code."
    info['product_code'] = fld
    return info['product_code']


def parseANMNinfo(info, errors):
    """
    Parse the generic IMOS filename fields to extract ANMN-specific
    information.
    """

    # site_code is the same as, or the first part of, the platform_code
    info['site_code'] = info['platform_code'].split('-')[0]

    # extract deployment and instrument details from product_code
    m = re.findall('(%s[a-zA-Z-]*?)-(\d{4,6})-(.+)-([0-9.]+)' % info['site_code'], 
                   info['product_code'])
    if m:
        info['platform_code'], deployDate, info['instrument'], depth = m[0]
        info['deployment_code'] = info['platform_code'] + '-' + deployDate
        info['instrument_depth'] = float(depth)
    else:
        errors.append('Can\'t extract deployment code & instrument from "%s"' % 
                      info['product_code'])

    return info, errors



def parseFilename(filename, minFields=6):
    """
    Parse a filename string, check that it meets the IMOS convention
    and return the information contained in it.
    """
    info = {'extension':'',
            'facility':'', 
            'sub_facility':'', 
            'data_code':'', 
            'start_time':'', 
            'site_code':'',  
            'platform_code':'', 
            'file_version':'', 
            'product_code':'', 
            'deployment_code':'', 
            'instrument':'', 
            'instrument_depth':0, 
            'end_time':'', 
            'creation_time':'',
            'dataset_part':''}
    errors = []
    minFields = max(minFields, 6)

    # remove file extension
    extp = filename.rfind('.')
    if extp >= 0 and extp < len(filename)-1:
        info['extension'] = filename[extp+1:]
    else:
        errors.append('No file extension.')

    # split the string into fields and check the number of fields
    field = filename[:extp].split('_')
    if len(field) < minFields: 
        errors.append('Less than %d fields in filename.' % minFields)
    # now extract as much info as we can from each field...
        

    # project name 
    if field:
        fld = field.pop(0)
        if fld <> 'IMOS':
            errors.append('Unknown project "'+fld+'".')


    # facility and sub-facility
    if field:
        fld = field.pop(0)
        if fld in subFacilities:
            info['facility'], info['sub_facility'] = fld.split('-')
        else:
            errors.append('Unknonwn sub-facility "'+fld+'".')


    # data codes
    if field:
        fld = field.pop(0)
        if re.match('['+dataCodeLetters+']+$', fld): 
            info['data_code'] = fld
        else:
            errors.append('Invalid data code "'+fld+'".')
            if re.match('[\dTZ]+$', fld):  
                # looks like start date, so let's parse it
                field.insert(0, fld)


    # start date/time
    if field:
        fld = field.pop(0)
        # require full date/time strings for netCDF files
        dt = parseTime(fld, strict=(info['extension']=='nc'))  
        if dt:
            info['start_time'] = dt
        else:
            errors.append('Invalid start time "'+fld+'".')


    # site & platform code
    if field:
        info['platform_code'] = field.pop(0)


    # file version
    if field:
        info['file_version'] = field.pop(0)


    # the remaining fields are easier to parse from the end...
    field.reverse()
    parsers = [parseDatasetPart, parseCreationTime, parseEndTime, parseProductCode]
    for fld in field:
        for parse in parsers:
            if parse(fld, info, errors):
                parsers.remove(parse)
                break
        else:
            errors.append('Unable to parse "'+fld+'".')
            

    # extract any facility-specific info
    if info['facility'] == 'ANMN':
        info, errors = parseANMNinfo(info, errors)


    # return the values
    return info, errors



### Given the relevant information for a data set, create the correct filename
