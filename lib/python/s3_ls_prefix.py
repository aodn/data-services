#!/usr/bin/env python3
# script to list s3 object from an AODN bucket to stdout
# author: laurent Besnard

import argparse
import boto3
import sys
import os
import urllib

EXAMPLE_TEXT = """
Requirements:
  1) set up credentials with `aws configure` (binary coming from awscli package)
  2) download file
     https://github.com/aodn/cloud-deploy/blob/master/sample-config/aws/config_projectofficer
     copy and rename to ~/.aws/config

Examples:
  ./s3_ls_prefix.py -p 'Defence_Technology_Agency-New_Zealand/Waverider_Buoys_C-20200615T000000Z/'
  ./s3_ls_prefix.py -b imos-test-data -p 'Defence_Technology_Agency'
  ./s3_ls_prefix.py -p IMOS/ACORN/gridded_1h-avg-current-map_QC/NWA/2021/07/ -o /tmp/nwa_dm
"""

URL_PREFIX="https://s3-ap-southeast-2.amazonaws.com"

def _s3_ls_bucket_prefix(bucket, prefix):
    s3 = boto3.resource('s3')
    my_bucket = s3.Bucket(bucket)

    s3_obj = []
    for object in my_bucket.objects.filter(Prefix=prefix):
        s3_obj.append(object.key)

    return s3_obj


def _download_s3_obj_flat(bucket, s3_obj_ls, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for f in s3_obj_ls:
        url='{prefix_url}/{bucket}/{object_path}'.format(prefix_url=URL_PREFIX,
                                                        bucket=bucket,
                                                        object_path=f)
        output_file = os.path.join(output_dir, os.path.basename(f))

        print('Downloading {f}'.format(f=f), file=sys.stdout)
        urllib.request.urlretrieve(url, output_file)


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser(epilog=EXAMPLE_TEXT,
                                     description='script to list/download s3 object from an AODN bucket to stdout',
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-p", "--prefix",
                        type=str,
                        help="s3 prefix - Example ''IMOS/SOOP'")

    parser.add_argument("-b", "--bucket",
                        default='imos-data',
                        type=str,
                        help="s3 bucket - default value is 'imos-data'")

    parser.add_argument("-o", "--output-dir",
                        type=str,
                        help="download listed objects to --output-dir")

    return parser.parse_args()


if __name__ == '__main__':

    vargs = args()

    prefix = vargs.prefix
    bucket = vargs.bucket
    os.environ['AWS_PROFILE'] = 'production-projectofficer'

    s3_obj_ls = _s3_ls_bucket_prefix(bucket, prefix)
    if vargs.output_dir:
        _download_s3_obj_flat(bucket, s3_obj_ls, vargs.output_dir)
    else:
        for f in s3_obj_ls:
            print(f, file=sys.stdout)

