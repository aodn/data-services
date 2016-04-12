#!/usr/bin/env sh

# $1 AUV campaign name on remote server to download
auv_campaign_download() {
    local campaign_name=$1; shift
    local log_file=$WIP_DIR/AUV/auv_rsync.log
    local auv_download_campaign_folder=$WIP_DIR/AUV/AUV_DOWNLOAD_CAMPAIGN
    local auv_server=rsync://129.78.210.231/released

    [ -z $campaign_name ] && { echo Campaign not entered does not exist on remote server, exit; exit 1; }
    [ -z $WIP_DIR ] && { echo WIP_DIR env var is unknown, exit; exit 1; }

    rsync $auv_server/$campaign_name | grep -q -E "$campaign_name" || { echo "Campaign $campaign_name" does not exist on remote server, exit; exit 1; }
    rsync --size-only --itemize-changes --log-file=$log_file --stats -uzhvrlD -L --progress $auv_server/$campaign_name $auv_download_campaign_folder/
}

auv_campaign_download "$@"
