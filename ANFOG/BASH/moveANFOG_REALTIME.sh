#!/bin/bash

#input_directories="/mnt/imos-t4/IMOS/staging/ANFOG/realtime/slocum_glider/./ /mnt/imos-t4/IMOS/staging/ANFOG/realtime/seaglider/./ /mnt/imos-t4/IMOS/staging/ANFOG/realtime/./"

#number_of_files_in_dir() {
#	local directory=$1; shift
#	local -i number_of_files_in_directory=`ls -1 $directory`
#	echo $number_of_files_in_directory
#}

rsync -aR  -O --remove-source-files  --include '+ */' --include '*.png' --include '*.txt' --exclude '- *' /mnt/imos-t4/IMOS/staging/ANFOG/realtime/slocum_glider/./ /mnt/imos-t4/IMOS/public/ANFOG/Realtime/slocum_glider
rsync -aR -O --remove-source-files  --include '+ */' --include '*.png' --exclude '- *' /mnt/imos-t4/IMOS/staging/ANFOG/realtime/seaglider/./ /mnt/imos-t4/IMOS/public/ANFOG/Realtime/seaglider
rsync -avR -O --remove-source-files /mnt/imos-t4/IMOS/staging/ANFOG/realtime/./ /mnt/opendap/1/IMOS/opendap/ANFOG/REALTIME

#for directory in $input_directories; do
#	if [ `number_of_files_in_directory` -eq 0 ]; then
#		echo "directory $directory was empty!"
#	fi
#done
