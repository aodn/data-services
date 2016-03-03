#!/bin/bash

declare -r SRS_OC_LJCO_AERONET_FILENAME="Lucinda.lev20"
declare -r SRS_OC_LJCO_AERONET_PATH="SRS/OC/LJCO/AERONET/$SRS_OC_LJCO_AERONET_FILENAME"

# main
# $1 - file to handle
main() {
    local file=$1; shift

    [ "`basename $file`" = "$SRS_OC_LJCO_AERONET_FILENAME" ] || \
        file_error "Filename must be '$SRS_OC_LJCO_AERONET_FILENAME'"

    s3_put $file IMOS/$SRS_OC_LJCO_AERONET_PATH && rm -f $file
}

main "$@"
