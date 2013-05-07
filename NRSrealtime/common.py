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
    
