#!/usr/bin/env sh

# $1 AUV campaign name on remote server to download
# $2 dive_name string(optional)
auv_campaign_download() {
    local campaign_name=$1; shift
    local dive_name=$1;
    local log_file=$WIP_DIR/AUV/auv_rsync.log
    local auv_download_campaign_folder=$WIP_DIR/AUV/AUV_DOWNLOAD_CAMPAIGN
    local auv_server=rsync://129.78.210.231/released

    [ -z $campaign_name ] && { echo Campaign can not be an empty value, exit; exit 1; }
    [ -z $WIP_DIR ] && { echo WIP_DIR env var is unknown, exit; exit 1; }

    if [ -z $dive_name ]
    then
        rsync $auv_server/$campaign_name | grep -q -E "$campaign_name" || { echo "Campaign $campaign_name" does not exist on remote server, exit; exit 1; }
        rsync --chmod=D775,F664 --size-only --itemize-changes --log-file=$log_file --stats -uzhvrlD -L --progress $auv_server/$campaign_name $auv_download_campaign_folder/
    else
        rsync $auv_server/$campaign_name/$dive_name | grep -q -E "$dive_name" || { echo "Dive $dive_name" does not exist on remote server, exit; exit 1; }
        rsync --chmod=D775,F664 --size-only --itemize-changes --log-file=$log_file --stats -uzhvrlD -L --progress $auv_server/$campaign_name/$dive_name $auv_download_campaign_folder/$campaign_name/
    fi

}

auv_campaign_download "$@"
