#!/bin/bash

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

currentYear=`date -u +%Y`

# we want to scan every day from 2007 to current year on every site
for site in CBG SAG ROT COF TURQ BONC
do
	case $site in
	CBG)
		station1=TAN
		station2=LEI
		;;
	SAG)
		station1=CWI
		station2=CSP
		;;
	ROT)
		station1=GUI
		station2=FRE
		;;
	COF)
		station1=RRK
		station2=NNB
		;;
	TURQ)
		station1=GHED
		station2=LANC
		;;
	BONC)
		station1=BFCV
		station2=NOCR
		;;
	esac

	for year in `seq 2007 $currentYear`
	do
		for month in 01 02 03 04 05 06 07 08 09 10 11 12
		do
			for day in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
			do
				# we check that the radial folders exist
				radial1Dir="$OPENDAP/ACORN/radial/$station1/$year/$month/$day"
				radial2Dir="$OPENDAP/ACORN/radial/$station2/$year/$month/$day"
				
				if [ -d "$radial1Dir" -a -d "$radial2Dir" ]; then
					# we check that the vector folder exists
					vectorDir="$OPENDAP/ACORN/gridded_1h-avg-current-map_non-QC/$site/$year/$month/$day"
					
					if [ -d "$vectorDir" ]; then
						# we retrieve the most recent date of last modified radial files
						radial1DirLastDate=`find $radial1Dir -type f -name "*.nc" -exec stat \{} --printf="%Y\n" \; | sort -n -r | head -1` # in seconds since epoch
						radial2DirLastDate=`find $radial2Dir -type f -name "*.nc" -exec stat \{} --printf="%Y\n" \; | sort -n -r | head -1` # in seconds since epoch
						if [ $radial1DirLastDate -gt $radial2DirLastDate ]; then
							radialDirLastDate=$radial1DirLastDate
						else
							radialDirLastDate=$radial2DirLastDate
						fi
						
						# we retrieve the most recent date of last modified vector files
						vectorDirLastDate=`find $vectorDir -type f -name "*.nc" -exec stat \{} --printf="%Y\n" \; | sort -n -r | head -1` # in seconds since epoch
						
						# we compare last modified radial to last modified vector to decide if vector is likely to be up to date
						# This is not as accurate as if we would check on hourly basis rather than daily...
						if [ $radialDirLastDate -gt $vectorDirLastDate ]; then
							echo "$vectorDir needs to be re-processed"
							if [ ${#site} -eq 3 ]; then
								radar_non_QC.sh "{'$site'}" "'$year$month$day"T003000"'" "'$year$month$day"T233000"'" "{}" "''" "''"
							else
								radar_non_QC.sh "{}" "''" "''" "{'$site'}" "'$year$month$day"T000000"'" "'$year$month$day"T230000"'"
							fi
						fi
					else
						echo "$vectorDir needs to be processed"
						if [ ${#site} -eq 3 ]; then
							radar_non_QC.sh "{'$site'}" "'$year$month$day"T003000"'" "'$year$month$day"T233000"'" "{}" "''" "''"
						else
							radar_non_QC.sh "{}" "''" "''" "{'$site'}" "'$year$month$day"T000000"'" "'$year$month$day"T230000"'"
						fi
					fi
				fi
			done
		done
	done
done
