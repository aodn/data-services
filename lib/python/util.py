#!/usr/bin/env python
"""
various utils which don't fit anywhere else
"""

def md5_file(file):
    """
    returns the md5 checksum of a file
    """
    import hashlib
    hash = hashlib.md5()
    with open(file, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash.update(chunk)
    return hash.hexdigest()

