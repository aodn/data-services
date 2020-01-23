#!/usr/bin/env python3
# -*- coding: utf-8 -*-
""" simple script to list all soop sst nrt files to be deleted as they are many
duplicates on S3 and the DB. Files with the latest creation date will be kept.

1) create a list of urls from the DB
\o soop_sst_url_ls;
select url from soop_sst.soop_sst_nrt_trajectory_map;

2)
then do a bit of cleaning of the text file, by removing the verital bars (under vim)
%s#│ ##g
%s# │##g

3)
then run the following script
This will create a new file soop_sst_nrt_duplicates_to_rm
which can be used in conjunction with po_s3_del

for f in `cat soop_sst_nrt_duplicates_to_rm | head -1`; do
    po_s3_del $f;
    done;
"""

import collections

from datetime import datetime

with open("soop_sst_url_ls") as f:
    soop_url_ls = f.read().splitlines()

# split url on creation date
soop_sst_split_creation_date = [x.rsplit('_C-') for x in soop_url_ls]
soop_sst_split_no_creation_date = [x.rsplit('_C-')[0] for x in soop_url_ls]


duplicates_no_creation_date = [item for item, count in collections.Counter(soop_sst_split_no_creation_date).items() if count > 1]
duplicates_no_creation_date.sort()


# for each bundle of duplicates, create a list of file to delete
list_files_to_rm = []
for i in range(len(duplicates_no_creation_date)):
    duplicate_bundle = [s for s in soop_url_ls if duplicates_no_creation_date[i] in s]

    # find which creation date is the oldest and remove others
    url_prefix_uniq = ([x.rsplit('_C-')[0] for x in duplicate_bundle])[0]
    bundle_creation_date = [x.rsplit('_C-')[1] for x in duplicate_bundle]
    bundle_creation_date = [x.rsplit('.nc')[0] for x in bundle_creation_date]

    datetime_object = [datetime.strptime(x, '%Y%m%dT%H%M%SZ') for x in bundle_creation_date]

    # we remove the max date to get a list of creation date to remove
    datetime_object.remove(max(datetime_object))
    creation_date_to_rm = datetime_object

    # recreate filenames to delete from S3
    list_files_to_rm.append(['{}_C-{}.nc'.format(url_prefix_uniq, x.strftime("%Y%m%dT%H%M%SZ")) for x in creation_date_to_rm])


flat_list = [item for sublist in list_files_to_rm for item in sublist]
with open('soop_sst_nrt_duplicates_to_rm', 'wb') as fp:
    fp.write("\n".join(flat_list))
