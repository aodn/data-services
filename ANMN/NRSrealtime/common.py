#! /usr/bin/env python
#
# Bits of commonly used code for moving files around.

import os


def upload(fileName, destDir, delete=None, log='upload.log'):
    """
    Check that destDir exists and create it if not. Then if delete is
    given, delete any files matching that pattern within destDir.
    Finally, copy fileName into destDir. Return True if no errors
    occurred, False otherwise.
    """
    err = 0
    if not os.path.isdir(destDir):
        try:
            os.makedirs(destDir)
        except:
            return False
    if delete:
        delPath = os.path.join(destDir, delete)
        if os.popen('ls ' + delPath).read():
            cmd = 'rm -v ' + delPath + '>>'+log
            err += os.system(cmd) > 0
    cmd = '  '.join(['cp -v', fileName, destDir, '>>'+log])
    err += os.system(cmd)

    return err == 0
    

def preProcessCSV(inFile, nCol=0, sortKey='1', fieldSep=',', outFile=None):
    """
    Sort a CSV file according to the rows specified in sortKey,
    removing duplicates and incomplete rows (rows with less than nCol
    columns). The result is stored in a new file. If outFile is not
    specified, it is derived by prepending 'pp' to the input filename.
    Returns the name of the output file if successful.

    Uses shell commands head, tail, sort and egrep.
    See the manpage for the sort shell command for the full KEYDEF
    syntax to use in sortKey. The default is to use all columns.

    An alternative field separator can begiven using fieldSep (default
    is ',').
    """

    # check inputs
    assert nCol, 'Expected number of columns must be > 0.'
    assert os.path.isfile(inFile), '%s is not a file' % infile
    if not outFile:
        p, f = os.path.split(inFile)
        outFile = os.path.join(p, 'pp'+f)

    # copy header to output file
    cmd = 'head -1 %s > %s' % (inFile, outFile)
    if os.system(cmd) != 0:
        return None

    # Build commands to skip header on first line ...
    tailCmd = 'tail -n +2 %s' % inFile

    # sort and remove duplicates ...
    sortCmd = 'sort --unique --field-separator=%s --key=%s' % (fieldSep, sortKey)

    # and remove invalid rows.
    grepCmd = 'egrep ".*(,.*){%d}"' % (nCol-1)

    # Put them all together and run them
    cmd = ' | '.join((tailCmd, sortCmd, grepCmd)) + ' >> ' + outFile
    if os.system(cmd) == 0:
        return outFile
    else:
        return None
