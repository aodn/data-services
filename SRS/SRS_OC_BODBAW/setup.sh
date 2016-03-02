#!/usr/bin/env bash
# Setup the environment to use to process the BODBAW data on a LINUX 64bits environment


initialisePerl() {
    # to do the first time CPAN is ran
    (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan ;
}

installPerlPackages() {
    # install depedencies
    perl -MCPAN -e ' install YAML';
    perl -MCPAN -e ' install Locale::Recode';
    perl -MCPAN -e ' install Unicode::Map';
    perl -MCPAN -e ' install Spreadsheet::ParseExcel';
    perl -MCPAN -e ' install Spreadsheet::ParseExcel::FmtUnicode';
    perl -MCPAN -e ' install Text::CSV_XS';
    perl -MCPAN -e ' install HTML::Template';
}

downloadPackage_xls2csv() {
    # download xls2csv Perl package
    curl -L http://search.cpan.org/CPAN/authors/id/K/KE/KEN/xls2csv-1.07.tar.gz -o xls2csv-1.07.tar.gz
    mkdir xls2csv_source
    tar zxpfv xls2csv-1.07.tar.gz -C xls2csv_source
    cd xls2csv_source/xls2csv-1.07

    stringtoFind="'sep_char'    => ',',"
    stringtoReplace="'sep_char'    => '|',"

    # modify separation char for CSV files.
    sed -i.bak "s/$stringtoFind/$stringtoReplace/g" script/xls2csv
    mv script/xls2csv script/xls2csv_bodbaw

    stringtoFind="xls2csv"
    stringtoReplace="xls2csv_bodbaw"
    sed -i.bak "s/$stringtoFind/$stringtoReplace/g" script/xls2csv_bodbaw
    sed -i.bak "s/$stringtoFind/$stringtoReplace/g" Makefile.PL

    # install modified perl package with new name xls2csv_bodbaw
    perl Makefile.PL
    make
    make test
    make install

    cd ../..
    rm -rf xls2csv_source/
    rm xls2csv-1.07.tar.gz
}

addGitModule_imos_user_code_library() {
    gitRepo='imos-user-code-library'
    if [ ! -d lib/$gitRepo ]
        then
            git clone https://github.com/aodn/$gitRepo $gitRepo
    fi
}

isROOT() {
    if [ "$EUID" -ne 0 ]
      then echo "Please run as root"
      exit
    fi
}

main() {
    isROOT
    initialisePerl
    installPerlPackages
    downloadPackage_xls2csv
    addGitModule_imos_user_code_library
}


main "$@"
