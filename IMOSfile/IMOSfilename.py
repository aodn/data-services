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
    info = {'facility':'', 'data-code':'', 'start-time':'', 'site-code':'', 'file-version':'', 'product-code':'', 'deployment-code':'', 'instrument':'', 'end-time':'', 'creation-time':''}
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
        info['facility'] = fld
    else:
        errors.append('Unknonwn sub-facility "'+fld+'".')


    # data codes
    info['data-code'] = field.pop(0)


    # start date/time
    fld = field.pop(0)
    dt = parseTime(fld)
    if dt:
        info['start-time'] = dt
    else:
        errors.append('Invalid start time "'+fld+'".')


    # site code
    info['site-code'] = field.pop(0)


    # file version
    info['file-version'] = field.pop(0)


    # deployment & product code
    if not field: return info, errors
    prod = field.pop(0)
    info['product-code'] = prod
    m = re.findall('(%s-\d{4})-(.*)' % info['site-code'], prod)
    if m:
        info['deployment-code'], info['instrument'] = m[0]
    else:
        errors.append('Can\'t extract deployment code from "%s"' % prod)

    # end time
    if not field: return info, errors
    fld = field.pop(0)
    if fld.find('END-') == 0  and  len(fld) > 4:
        dt = parseTime(fld[4:])
        if dt:
            info['end-time'] = dt
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
            info['creation-time'] = dt
        else:
            errors.append('Invalid creation time "'+fld+'".')
    else:
        errors.append('Invalid creation time "'+fld+'".')


    # return the values
    return info, errors


### Given the relevant information for a data set, create the correct filename

