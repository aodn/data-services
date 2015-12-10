#!/bin/bash

TESTS="$TESTS lib/test/common/shunit2_test.sh"
TESTS="$TESTS lib/python/test_file_classifier.py"

TESTS="$TESTS ACORN/BASH/shunit2_test.sh"
TESTS="$TESTS ACORN/CurrentGenerator/CurrentGeneratorTestUnit.py"

TESTS="$TESTS ANMN/AM/test_dest_path.py"

TESTS="$TESTS SRS/srs_gridded_pipeline/shunit2_test_sst_destination_path.sh"

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
