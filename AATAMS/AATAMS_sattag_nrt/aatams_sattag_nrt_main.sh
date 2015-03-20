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
    # subsistute env var from config.txt
    source /dev/stdin <<< `envsubst  < config.txt | sed '/^#/ d' | sed '/^$/d' |  sed 's:":'\'':g'|  sed 's:\s*=:=:g' | sed 's:=\s*:=":g' | sed 's:$:":g' | sed 's:^:export :g'`
}


function run_matlab(){
    matlab -nodisplay -r "run  ('aatams_sattag_nrt_main.m');exit;"  2>&1 | tee  ${DIR}/${APP_NAME}.log ;
}


function run_rsync(){
    # rsync data between rsyncSourcePath and rsyncDestinationPath
    rsync --size-only --itemize-changes --delete-before  --stats -uhvrD  --progress ${data_wip_path}/NETCDF/  ${data_destination_path}/ ;
}


function main(){
    read_env

    APP_NAME=AATAMS_SATTAG_NRT
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


main