#! /usr/bin/env python
#
# Python module to parse, check and create filenames according to the
# IMOS convention.


#### DATA ###################################################################

# List of valid facility/sub-facility codes.
subFacilities = ('ANMN-NRS', 
                 'ANMN-NSW', 
                 'ANMN-QLD', 
                 'ANMN-SA', 
                 'ANMN-WA', 
                 'ANMN-PA')


#### FUNCTIONS ##############################################################

def parseTime(t):
    """
    Parse a date/time string within the filename and convert it into a
    datetime object.
    *** TO BE IMPLEMENTED ***
    """
    return t


def parseFilename(filename):
    """
    Parse a filename string, check that it meets the IMOS convention
    and return the information contained in it.
    """
    info = {}
    errors = []

    # remove file extension
    extp = filename.rfind('.')
    if extp >= 0 and extp < len(filename)-1:
        info['extension'] = filename[extp+1:]
    else:
        errors.append('No file extension.')

    # split the string into fields and check the value of each field is valid
    field = filename[:extp].split('_')
    if len(field) < 6: 
        errors.append('Less than 6 fields filename.')

    # project name   
    if field[0] == 'IMOS':
        info['project'] = field[0]
    else:
        errors.append('Unknown project "'+field[0]+'".')

    # facility and sub-facility
    if field[1] in subFacilities:
        info['facility'] = field[1]
    else:
        errors.append('Unknonwn sub-facility "'+field[1]+'".')

    # data codes
    info['data-code'] = field[2]

    # start date/time
    tt = parseTime(field[3])
    if tt:
        info['start-time'] = tt
    else:
        errors.append('Invalid start time "'+field[3]+'".')

    # return the values
    return info, errors


### Given the relevant information for a data set, create the correct filename

