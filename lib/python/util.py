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

def get_git_revision_script_url(file_path):
    import os
    import subprocess
    """
    file_path is the local file path from a git repo
    returns the github url with the hash value of the current HEAD
    """
    curr_dir = os.getcwd()
    os.chdir(os.path.dirname(file_path)) # need to chg dir to run git commands

    repo_username_name = (subprocess.check_output(['git', 'config', '--get', 'remote.origin.url']).strip()).split(':')[1]
    repo_name          = repo_username_name.split('/')[1]
    hash_val           = subprocess.check_output(['git', 'rev-parse', 'HEAD']).strip()
    script_rel_path    = file_path[file_path.index(repo_name) + len(repo_name) + 1:]

    os.chdir(curr_dir)
    return 'www.github.com/%s/blob/%s/%s' % (repo_username_name, hash_val, script_rel_path)
