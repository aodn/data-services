#!/bin/bash

# Avoid running this script if variables are undefined
set -u
umask 022

ARGO_SRC=vdmzrs.ifremer.fr::argo
ARGO_WIP_DIR=$WIP_DIR/Argo/dac
EXTRA_RSYNC_OPTS=''

# useful for testing, uncomment to iterate on a much smaller data set
#EXTRA_RSYNC_OPTS='--exclude=aoml --exclude=bodc --exclude=coriolis --exclude=csio --exclude=csiro --exclude=incois --exclude=jma --exclude=kma --exclude=kordi --exclude=meds'

# Actual rsync command for argo
rsync_argo() {
    mkdir -p $ARGO_WIP_DIR
    rsync $EXTRA_RSYNC_OPTS --exclude=.snapshot --times --delete -i -rzv $ARGO_SRC $ARGO_WIP_DIR
}

# main
main() {
    if [ "$(ls -A $ERROR_DIR/ARGO)" ]; then
        echo "Unable to run rsync as $ERROR_DIR/ARGO is not empty"
        exit 1
    fi

    local tmp_rsync_output_file=`mktemp`
    rsync_argo | tee $tmp_rsync_output_file

    # regardless of the success/failure of the rsync command, we still must
    # handle transferred files. otherwise we'll end up with inconsistencies

    mv $tmp_rsync_output_file $INCOMING_DIR/Argo/argo_rsync.`date +%Y%m%d-%H%M%S`.rsync_manifest
}

main "$@"
