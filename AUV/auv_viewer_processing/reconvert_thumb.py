#!/usr/bin/env python
# -*- coding: utf-8 -*-
# before usage, please generate list of tiff files
# \o auv_images_ls
# select 'IMOS/AUV/' || campaign_code || '/' || site_code || '/' || image_folder
# || '/' || image_filename || '.tif' from auv_viewer_track.auv_images_vw;


import gzip
import os
import re

from urllib2 import urlopen
from functools import partial
from wand.image import Image
from multiprocessing import Pool, cpu_count


def list_files(fname):
    "read content of text file into list. handle tgz file (smaller for github)"
    if fname.endswith('.gz'):
        with gzip.open(fname, 'rb') as f:
            return f.readlines()

    else:
        with open(fname) as f:
            return f.readlines()


def _generate_geotiff_thumbnail(thumbnail_dir_path, geotiff_name):
    """
    download the orginal file on S3
    generate the thumbnail of one image
    """
    geotiff_path       = [s for s in geotiff_ls if geotiff_name in s][0]
    s3_bucket_url      = 'http://s3-ap-southeast-2.amazonaws.com/imos-data/'
    thumbnail_rel_path = re.sub('i2.*gtif', 'i2jpg', geotiff_path, flags=re.DOTALL).replace('IMOS/AUV/', 'IMOS/AUV/auv_viewer_data/thumbnails/').replace('.tif', '.jpg')
    thumbnail_path     = os.path.join(thumbnail_dir_path, thumbnail_rel_path)

    if not os.path.exists(os.path.dirname(thumbnail_path)):
        os.makedirs(os.path.dirname(thumbnail_path))

    full_res_rel_path = geotiff_path.replace('IMOS/AUV/', 'IMOS/AUV/auv_viewer_data/full_res/').replace('.tif', '.jpg')
    full_res_path     = os.path.join(thumbnail_dir_path, full_res_rel_path)

    if not os.path.exists(os.path.dirname(full_res_path)):
        os.makedirs(os.path.dirname(full_res_path))

    try:
        f = urlopen('%s%s' % (s3_bucket_url, geotiff_path))
        with Image(file=f) as img:
            img.save(filename=full_res_path)
            img.resize(453, 341)
            img.save(filename=thumbnail_path)

        with open('thumbnails_already_done', "a") as g:
            g.write("%s\n" % os.path.basename(thumbnail_path))

        f.close()
    except Exception:
        pass


def generate_geotiff_thumbnails_dive(geotiff_dive_list, thumbnail_dir_path):
    """
    generate the thumbnails of geotiffs used by the auv viewer. This is done in
    a multithreading way by looking at the number of cores available on the machine
    files go to wip_dir
    """
    if not os.path.exists(thumbnail_dir_path):
        os.makedirs(thumbnail_dir_path)

    partial_job = partial(_generate_geotiff_thumbnail, thumbnail_dir_path)
    n_cores     = cpu_count()
    pool        = Pool(n_cores)
    pool.map(partial_job, geotiff_dive_list)
    pool.close()
    pool.join()


if __name__ == '__main__':
    global geotiff_ls

    thumbnail_dir_path = 'output_thumbnails'
    fname = 'auv_images_ls'
    with open(fname) as f:
        geotiff_ls = f.readlines()

    geotiff_ls = map(lambda s: s.strip(), geotiff_ls)

    # touch file for list of files already processed
    if not os.path.exists('thumbnails_already_done'):
        open('thumbnails_already_done', 'w').close()
        list_files_all_basename        = [os.path.basename(g) for g in geotiff_ls]
    else:
        list_files_already_reprocessed = list_files('thumbnails_already_done')
        list_files_all_basename        = [os.path.basename(g) for g in geotiff_ls]

        # rough cleaning
        list_files_all_basename        = [os.path.splitext(x)[0] for x in list_files_all_basename]
        list_files_already_reprocessed = [os.path.splitext(x)[0] for x in list_files_already_reprocessed]

        # comparing list of basenames, ie without dir
        list_files_to_process = list(set(list_files_all_basename).difference(list_files_already_reprocessed))

    generate_geotiff_thumbnails_dive(list_files_to_process, thumbnail_dir_path)
