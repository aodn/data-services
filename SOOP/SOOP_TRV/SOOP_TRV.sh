#!/bin/bash

read_env() {
    export LOGNAME=projectofficer
    export HOME=/home/projectofficer
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games

    local script_bash_path=`readlink -f $0`
    export script_dir=`dirname $script_bash_path`
    local env_path=$script_dir"/env"

    if [ ! -f `readlink -f $env_path` ]
    then
        echo "env file does not exist. exit" 2>&1
        exit 1
    fi

    # read environmental variables from config.txt
    source `readlink -f $env_path`

    # subsistute env var from config.txt | delete lines starting with # | delete empty lines | remove empty spaces | add export at start of each line
    source /dev/stdin <<< `envsubst  < $script_dir/config.txt | sed '/^#/ d' | sed '/^$/d' | sed 's:\s::g' | sed 's:^:export :g' `

    # load IMOS CONVENTIONS, ACKNOWLEDGEMENT, DATA_CENTER, DATA_CENTER_EMAIL ... global attributes values as env variables
    source $script_dir"/lib/netcdf/netcdf-cf-imos-compliance.sh"
}

assert_var() {
    [ x"$1" = x ] && echo "undefined variable " && exit 1
}

run_python() {
    assert_var $script_dir

    local aims_python_script_path=subroutines/soop_trv.py
    local core_logic_test_aims_python_script_path=subroutines/soop_trv_data_validation_test.py

    # run main code if unittest succeeds
    python ${script_dir}/${core_logic_test_aims_python_script_path} && python ${script_dir}/${aims_python_script_path} 2>&1 | tee ${data_wip_path}/${script_name}.log ;
}


main() {
    read_env
    assert_var $data_wip_path
    mkdir -p $data_wip_path
    local script_name=process
    local lockfile=${data_wip_path}/${script_name}.lock

    {
        if ! flock -n 9
        then
          echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
          exit 1
        fi

        echo START ${script_name}
        run_python
        rm $lockfile

    } 9>"$lockfile"
}

main "$@"
