#!/bin/bash
#to call the script, either ./main.sh XBT  or ./main.sh ASF_SST
TMPDIR=/tmp

function read_env(){
    export LOGNAME=projectofficer
    export HOME=/home/projectofficer
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games

    script_bash_path=`readlink -f $0`
    script_dir=`dirname $script_bash_path`
    env_path=$script_dir"/env"
    if [ ! -f `readlink -f $env_path` ]
    then
        echo "env file does not exist. exit" 2>&1
        exit 1
    fi

    # read environmental variables from config.txt
    source `readlink -f $env_path`

    # subsistute env var from config.txt | delete lines starting with # | delete empty lines | remove empty spaces | add export at start of each line
    source /dev/stdin <<<  `envsubst  < $script_dir/config.txt | sed '/^#/ d' | sed '/^$/d' | sed 's:\s::g' | sed 's:^:export :g' `
}

function process_xbt(){
    echo "START PROCESS XBT"
    mkdir -p `dirname $logfile_xbt_path`
    assert_var $script_dir
    assert_var $temporary_data_folder_sorted_xbt_path
    assert_var $destination_incoming_data_public_soop_xbt_path
    assert_var $temporary_data_folder_sorted_xbt_path

    python ${script_dir}"/SOOP_XBT_RT.py" 2>&1
    rsyncSourcePath=$temporary_data_folder_sorted_xbt_path

    # push a manifest file containing ONLY new csv files who didn't go through the pipeline yet
    # remove $manifest_previoulsy_processed_csv_append to manually force the reprocess of all files
    local manifest_previoulsy_processed_csv_append=$temporary_data_folder_sorted_xbt_path/manifest_soop_xbt_nrt_success_append.csv
    touch $manifest_previoulsy_processed_csv_append # need to touch for first run if we went to append lines to file
    local manifest_newly_created_csv=`mktemp`
    local manifest_incoming=${destination_incoming_data_public_soop_xbt_path}/IMOS_SOOP-XBT_NRT_fileList.csv
    find $rsyncSourcePath -type f -name "IMOS_SOOP-XBT_*.csv" | sort > $manifest_newly_created_csv

    # get the difference of files already pushed to s3 sucessfuly
    comm -13 $manifest_previoulsy_processed_csv_append $manifest_newly_created_csv > $manifest_incoming
}

function process_asf_sst(){
    echo "START PROCESS ASF SST"

    assert_var $script_dir
    assert_var $temporary_data_folder_sorted_asf_sst_path
    assert_var $destination_production_data_opendap_soop_asf_sst_path

    python ${script_dir}"/SOOP_BOM_ASF_SST.py" 2>&1 | tee  ${TMPDIR}/${APP_NAME}".log2"

    # rsync data between rsyncSourcePath and rsyncDestinationPath
    rsyncSourcePath=$temporary_data_folder_sorted_asf_sst_path
    rsync  --itemize-changes  --stats -tzhvr --remove-source-files  --progress ${rsyncSourcePath}/  ${destination_production_data_opendap_soop_asf_sst_path}/ ;
}


function assert_var(){
    [ x"$1" = x ] && echo "undefined variable " && exit 1
}


function main(){
    local option="$1"; shift
    local valid_options="XBT ASF_SST"

    APP_NAME=SOOP_SST_ASF_XBT
    lockfile=${TMPDIR}/${APP_NAME}.lock

    read_env
    {
        if ! flock -n 9
        then
            echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
            exit 1
        fi

        echo $valid_options | grep -q "\<$option\>" || echo "Unknown optional argument. Try ./main.sh XBT  or ./main.sh ASF_SST" 2>&1
        [[ $option == "XBT" ]] && process_xbt
        [[ $option  == "ASF_SST" ]] && process_asf_sst

        rm $lockfile

    } 9>"$lockfile"
}

main "$@"
