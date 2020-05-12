#!/bin/bash

if [ "$DOCKER_TESTING" == "true" ]; then
    echo "DOCKER_TESTING detected, installing dependencies"
    docker/install.sh --user
else
    echo "DOCKER_TESTING not detected, continuing"

fi

TESTS="$TESTS lib/test/common/shunit2_test.sh"

TESTS="$TESTS lib/test/python/test*.py"


main() {
    cd `dirname $0`

    export PYTHONPATH=$PWD:$PWD/lib/python

    local -i retval=0

    for test in $TESTS; do
        echo "#############################"
        echo "Executing: '$test'"
        echo "#############################"
        $test
        let retval=$retval+$?
        echo "#############################"
    done

    return $retval
}

main "$@"
