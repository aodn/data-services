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
    """
    file_path is the local file path in a github repo
    returns the github url with the hash value of the current HEAD
    Only handles `git config --get remote.origin.url` output in the form defined
    in pattern variable
    """
    from git import Repo
    import os
    import re

    repo = Repo(file_path, search_parent_directories=True)
    hash_val = str(repo.commit('HEAD'))
    script_rel_path = os.path.relpath(file_path, repo.working_tree_dir)

    pattern = '(.*)@(.*):(.*)/(.*)$'
    regroup = re.search(pattern, repo.remotes.origin.url)
    try:
        user, host, organisation, repo_name = regroup.group(1, 2, 3, 4)
    except ValueError:
        # the default message is very vague, so rethrow with a more descriptive message
        raise ValueError('Cannot parse remote.origin.url')

    return '{0}/{1}/{2}/blob/{3}/{4}'.format(host, organisation, re.sub('\.git$', '', repo_name), hash_val, script_rel_path)
