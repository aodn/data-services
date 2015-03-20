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

    APP_NAME=AERONET_DOWNLOAD
    DIR=/tmp
    lockfile=${DIR}/${APP_NAME}.lock

    {

        if ! flock -n 9
        then
          echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
          exit 1
        fi

        echo START ${APP_NAME}
        run_python



    } 9>"$lockfile"
}


function run_python(){
    python downloadAeronetData.py  2>&1 | tee  ${DIR}/${APP_NAME}.log ;
}




main
