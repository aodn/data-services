#!/bin/bash

ACORN_REGEX='^IMOS_ACORN_[[:alpha:]]{1,2}_[[:digit:]]{8}T[[:digit:]]{6}Z_[[:alpha:]]{3,4}_FV00_(radial|sea-state|wavespec|windp|wavep|1-hour-avg)\.nc$'

export ACORN_REGEX

main() {
    `dirname $0`/../incoming_handler_common.sh "$@"
}

# don't run main if running shunit
if [[ `basename $0` =~ ^shunit2_.* ]]; then
    true
else
    main "$@"
fi

