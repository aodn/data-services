#!/usr/bin/env python3
# script to list s3 object from an AODN bucket to stdout
# requires credential to be set up with `aws configure`
# Example: ./s3_ls_prefix.py -p 'Defence_Technology_Agency-New_Zealand/Waverider_Buoys_C-20200615T000000Z/'
# author: laurent Besnard

import argparse
import boto3
import sys
import os


def _s3_ls_bucket_prefix(bucket, prefix):
    s3 = boto3.resource('s3')
    my_bucket = s3.Bucket(bucket)

    s3_obj = []
    for object in my_bucket.objects.filter(Prefix=prefix):
        s3_obj.append(object.key)

    return s3_obj


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--prefix",
                        type=str,
                        help="s3 prefix - Example ''IMOS/SOOP'")

    parser.add_argument("-b", "--bucket",
                        default='imos-data',
                        type=str,
                        help="s3 bucket - default value is 'imos-data'")

    return parser.parse_args()


if __name__ == '__main__':

    vargs = args()

    prefix = vargs.prefix
    bucket = vargs.bucket
    os.environ['AWS_PROFILE'] = 'production-projectofficer'

    s3_obj = _s3_ls_bucket_prefix(bucket, prefix)
    for f in s3_obj:
        print(f, file=sys.stdout)
