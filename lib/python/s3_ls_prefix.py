#!/usr/bin/env python3
# script to list s3 object from an AODN bucket to stdout
# author: laurent Besnard

import argparse
import boto3
import sys
import os
import urllib
from botocore.exceptions import ClientError

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
   ./s3_ls_prefix.py -l CSIRO/Climatology/Ocean_Acidification/OA_Reconstruction.nc
  ./s3_ls_prefix.py -v CSIRO/Climatology/Ocean_Acidification/OA_Reconstruction.nc h40zqcPFdSR1POV5Ihon3mH8nvt7SkgU
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

def _list_object_version(bucket, prefix):
   s3 = boto3.client('s3')
   try:
      result = s3.list_object_versions(Bucket=bucket, Prefix=prefix)
   except ClientError as e:
      raise Exception("boto3 client error in list_all_objects_version function: " + e.__str__())
   except Exception as e:
      raise Exception("Unexpected error in list_all_objects_version function of s3 helper: " + e.__str__())

   return result

def _download_file_version(bucket, prefix, versionid):
    s3 = boto3.client('s3')
    filename = os.path.basename(prefix)
    s3.download_file(bucket, prefix, filename, ExtraArgs={'VersionId': versionid})


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

    parser.add_argument("-l", "--listversion",
                        type=str,
                        help="list object version --listversion")

    parser.add_argument("-v", "--versionid", nargs=2 ,
                        type=str,
                        help="download the versionid of a given object. "
                             "Example IMOS/ANFOG/"
                             "IMOS_ANFOG_BCEOPSTUVN_20151021T035731Z_SL416_FV01_timeseries_END-20151027T015319Z.nc"
                             " pAo_g3MuONfNf5wIgeq0ff5WHswj_Wbd --versionid")

    return parser.parse_args()


if __name__ == '__main__':

    vargs = args()
    if vargs.prefix:
        prefix = vargs.prefix
    bucket = vargs.bucket
    os.environ['AWS_PROFILE'] = 'production-projectofficer'

    if vargs.output_dir:
        s3_obj_ls = _s3_ls_bucket_prefix(bucket, prefix)
        _download_s3_obj_flat(bucket, s3_obj_ls, vargs.output_dir)
    elif vargs.listversion:
        prefix = vargs.listversion
        res =_list_object_version(bucket, prefix)
        print(res['Prefix'])
        for values in res.values():
            if(isinstance(values, list)):
                for value in values:
                    print('VersionId:',value['VersionId'],'Lastmodified:', value['LastModified'])
        print('Number of versions', len(res['Versions']))
    elif vargs.versionid:
        object = vargs.versionid[0]
        versionid =  vargs.versionid[1]
        _download_file_version(bucket, object, versionid)
    else:
        s3_obj_ls = _s3_ls_bucket_prefix(bucket, prefix)
        for f in s3_obj_ls:
            print(f, file=sys.stdout)