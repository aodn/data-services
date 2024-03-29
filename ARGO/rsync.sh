#!/bin/bash

# Avoid running this script if variables are undefined
set -eu

ARGO_SRC=vdmzrs.ifremer.fr::argo
ARGO_WIP_DIR=$WIP_DIR/Argo/dac
EXTRA_RSYNC_OPTS="--chmod=D755,F644"

# useful for testing, uncomment to iterate on a much smaller data set
#EXTRA_RSYNC_OPTS='--exclude=aoml --exclude=bodc --exclude=coriolis --exclude=csio --exclude=csiro --exclude=incois --exclude=jma --exclude=kma --exclude=kordi --exclude=meds'

# Actual rsync command for argo
rsync_argo() {
    mkdir -p $ARGO_WIP_DIR
    rsync $EXTRA_RSYNC_OPTS --exclude=.snapshot --times --delete -i -rzv $ARGO_SRC $ARGO_WIP_DIR
}

# main
main() {
    # don't run rsync in case there are already some manifest files in the
    # ERROR_DIR or in the INCOMING_DIR. This is not ideal, as there could still
    # be a file being processed by the pipeline, but since there is no way to
    # communicate to the pipeline to get a status, this is the best we can do.
    if [ "$(ls -A $ERROR_DIR/ARGO)" ] || [ "$(ls -A $INCOMING_DIR/Argo)" ]; then
        echo "Unable to run rsync as $ERROR_DIR/ARGO is not empty"
        exit 1
    fi

    local tmp_rsync_output_file=`mktemp`
    trap "rm -f $tmp_rsync_output_file" EXIT
    rsync_argo | sort | uniq | tee $tmp_rsync_output_file

    # regardless of the success/failure of the rsync command, we still must
    # handle transferred files. otherwise we'll end up with inconsistencies

    # we remove simplified profiles (stating with S as we cannot handle them yet
    grep -v -e "/profiles/S.*\.nc$" $tmp_rsync_output_file > ${tmp_rsync_output_file}_trimmed
    mv ${tmp_rsync_output_file}_trimmed $tmp_rsync_output_file

    chmod 0664 $tmp_rsync_output_file
    mv $tmp_rsync_output_file $INCOMING_DIR/Argo/argo_rsync.`date +%Y%m%d-%H%M%S`.rsync_manifest
}

main "$@"
