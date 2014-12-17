#!/bin/bash

function read_env(){
    export LOGNAME=lbesnard
    export HOME=/home/lbesnard
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games

    if [ ! -f `readlink -f env` ]
    then
        echo "env file does not exist. exit" 2>&1
        exit 1
    fi

    # read environmental variables from config.txt
    source `readlink -f env`
    # subsistute env var from config.txt | delete lines starting with # | delete empty lines | remove empty spaces | add export at start of each line
    source /dev/stdin <<<  `envsubst  < config.txt | sed '/^#/ d' | sed '/^$/d' | sed 's:\s::g' | sed 's:^:export :g' `
}


function main(){
    read_env

    APP_NAME=AUV_VIEWER_DATA_PROCESS
    DIR=/tmp
    lockfile=${DIR}/${APP_NAME}.lock

    {

        if ! flock -n 9
        then
          echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
          exit 1
        fi

        echo START ${APP_NAME}

        run_matlab
        run_rsync


    } 9>"$lockfile"
}


function run_matlab(){
    matlab -nodisplay -r "run  ('AUV_Processing.m');exit;"  2>&1 | tee  ${DIR}/${APP_NAME}.log ;
}


function run_rsync(){
    #rsync netcdf files from public to opendap see http://silentorbit.com/notes/2013/08/rsync-by-extension/
    rsync --size-only --itemize-changes --stats -vaR   --exclude='*.log' --prune-empty-dirs ${released_campaign_path}/./*/*/hydro_netcdf  ${released_campaign_opendap_path}/;

    #rsync images from WIP to thumbnails and remove from WIP
    rsync --size-only --itemize-changes --stats   --progress --remove-source-files -vrD --relative -a --prune-empty-dirs  ${processed_data_output_path}/./*/*/i2jpg ${auv_viewer_thumbnails_path}/;

    #rsync csv outputs used by talend from WIP to private
    rsync  --size-only --itemize-changes --stats   --progress -vrD  -a --exclude i2jpg/   --include '*.csv' --exclude '*.mat' --exclude '*.txt' --prune-empty-dirs  ${processed_data_output_path}/ ${auv_csv_output_path}/;

}

main