#!/usr/bin/env python
"""
various utils which don't fit anywhere else
imports could be in functions for portability reasons
"""


def md5_file(file):
    """
    returns the md5 checksum of a file

    TODO : write unittest
    """
    import hashlib
    hash = hashlib.md5()
    with open(file, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash.update(chunk)
    return hash.hexdigest()


def list_files_recursively(dir, pattern):
    """
    Look recursievely for files in dir matching a certain pattern

    TODO : write unittest
    """
    import fnmatch
    import os

    matches = []
    for root, dirnames, filenames in os.walk(dir):
        for filename in fnmatch.filter(filenames, pattern):
            matches.append(os.path.join(root, filename))

    return matches
