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
                 'ANMN-PA')


#### FUNCTIONS ##############################################################

def parseTime(tStr):
    """
    Parse a date/time string within the filename and convert it into a
    datetime object.
    *** INCOMPLETE!!! ***
    """
    try:
        dt = datetime.strptime(tStr, '%Y%m%dT%H%M%SZ')
    except:
        return None

    return dt


def parseFilename(filename, minFields=6):
    """
    Parse a filename string, check that it meets the IMOS convention
    and return the information contained in it.
    """
    info = {'facility':'', 
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
            'creation_time':''}
    errors = []
    minFields = max(minFields, 6)

    # remove file extension
    extp = filename.rfind('.')
    if extp >= 0 and extp < len(filename)-1:
        info['extension'] = filename[extp+1:]
    else:
        errors.append('No file extension.')

    # split the string into fields and check the value of each field is valid
    field = filename[:extp].split('_')
    if len(field) < minFields: 
        errors.append('Less than %d fields in filename.' % minFields)
        return info, errors

        
    # project name 
    fld = field.pop(0)
    if fld <> 'IMOS':
        errors.append('Unknown project "'+fld+'".')


    # facility and sub-facility
    fld = field.pop(0)
    if fld in subFacilities:
        info['facility'], info['sub_facility'] = fld.split('-')
    else:
        errors.append('Unknonwn sub-facility "'+fld+'".')


    # data codes
    info['data_code'] = field.pop(0)


    # start date/time
    fld = field.pop(0)
    dt = parseTime(fld)
    if dt:
        info['start_time'] = dt
    else:
        errors.append('Invalid start time "'+fld+'".')


    # site & platform code
    info['platform_code'] = field.pop(0)
    info['site_code'] = info['platform_code'].split('-')[0]


    # file version
    info['file_version'] = field.pop(0)


    # deployment & product code
    if not field: return info, errors
    prod = field.pop(0)
    info['product_code'] = prod
    m = re.findall('(%s[a-zA-Z-]*?)-(\d{4,6})-(.+)-([0-9.]+)' % info['site_code'], prod)
    if m:
        info['platform_code'], deployDate, info['instrument'], depth = m[0]
        info['deployment_code'] = info['platform_code'] + '-' + deployDate
        info['instrument_depth'] = float(depth)
    else:
        errors.append('Can\'t extract deployment code & instrument from "%s"' % prod)

    # end time
    if not field: return info, errors
    fld = field.pop(0)
    if fld.find('END-') == 0  and  len(fld) > 4:
        dt = parseTime(fld[4:])
        if dt:
            info['end_time'] = dt
        else:
            errors.append('Invalid end time "'+fld+'".')
    else:
        errors.append('Invalid end time "'+fld+'".')


    # creation time
    if not field: return info, errors
    fld = field.pop(0)
    if fld.find('C-') == 0  and  len(fld) > 2:
        dt = parseTime(fld[2:])
        if dt:
            info['creation_time'] = dt
        else:
            errors.append('Invalid creation time "'+fld+'".')
    else:
        errors.append('Invalid creation time "'+fld+'".')


    # return the values
    return info, errors


### Given the relevant information for a data set, create the correct filename

