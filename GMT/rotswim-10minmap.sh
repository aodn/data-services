#! /bin/bash
#
#
#  ACORN most recent 10min vector current plots from netcdf files
#  downloaded from THREDDS server
#
# Author : Guillaume Galibert (from Lucy Wyatt model)
#
# to run ./rotswim-10minmap.sh
# 
# 

#VERBOSE=-V

# set times
# Fremantle radar is last to fire
FRE_MN='55'
FRE_CURDATESTR=`date -u +%Y-%m-%dT%H:$FRE_MN:00Z`
FRE_CURDATESEC=`date -u -d $FRE_CURDATESTR +%s`
FRE_YR=`date -u -d $FRE_CURDATESTR +%Y`
FRE_MH=`date -u -d $FRE_CURDATESTR +%m`
FRE_DY=`date -u -d $FRE_CURDATESTR +%d`
FRE_HR=`date -u -d $FRE_CURDATESTR +%H`

FRE_LYR=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%Y`
FRE_LMH=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%m`
FRE_LDY=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%d`
FRE_LHR=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%H`

# Guilderton radar fires 5min before
GUI_CURDATESEC=`echo $FRE_CURDATESEC' - 60 * 5' | bc`
GUI_CURDATESTR=`date -u -d @$GUI_CURDATESEC +%Y-%m-%dT%H:%M:00Z`
GUI_YR=`date -u -d $GUI_CURDATESTR +%Y`
GUI_MH=`date -u -d $GUI_CURDATESTR +%m`
GUI_DY=`date -u -d $GUI_CURDATESTR +%d`
GUI_HR=`date -u -d $GUI_CURDATESTR +%H`
GUI_MN=`date -u -d $GUI_CURDATESTR +%M`

GUI_LYR=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%Y`
GUI_LMH=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%m`
GUI_LDY=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%d`
GUI_LHR=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%H`

# plot range
# for rot
#WIDTH=-Jm1:1000000
WIDTH=-Jm1:400000
#RANGE="-R115/116./-32.5/-31.5"
RANGE="-R115.42/115.75/-32.08/-31.92"

# grid sampling
# every third replaced with every second
SAMP="2.9684m,4.4367m"

# vector scaling
#VSCAL="-Q0.1c/0.8c/0.4cn3"
VSCAL="-Q0.1c/1c/0.5cn3"

# colour coding
CSCLV="-T0/0.5/0.05"

# scale location
#SCALE="-L115.6/-32.38/-32/10" 	# long/lat of scale centre/lat of scaling/length
SCALE="-L115.69/-31.925/-32/10"

# rest is site independent
SPATH=$OPENDAP'/ACORN/radial/'
FEND='_FV00_radial.nc'

OPATH=$ACORN_EXP'/GMT/'
LPATH=$PUBLIC'/ACORN/Rottnest_swim/10min_avg/'
nend='.nc'
pend='.ps'
eend='.png'

TPATH='/tmp/'$$'/'

RES=-Df
SEA_COLOUR=220/220/255
LAND_COLOUR=220/255/220
RADAR_COLOUR=255/0/0
WIND2_COLOUR=0/0/255
WIND1_COLOUR=255/0/0

# don't change this.
OPTS="${VERBOSE} ${RANGE} ${WIDTH}"

LASTDATESEC=`cat $OPATH'last_10min_rot.txt'`

echo 'Plot latest 10min averaged ROT files :'

isFirst=1
while test $FRE_CURDATESEC -ge $LASTDATESEC
do
	# want to search backwards in time to find latest couple of adjacent files on the system

	# from here is date specific
	# let's find Fremantle radar latest radial file
	FRE_DATLAB=$FRE_DY"/"$FRE_MH"/"$FRE_YR
	FRE_DATTIM=$FRE_YR$FRE_MH$FRE_DY'T'$FRE_HR$FRE_MN'00Z'
	FRE_LDATTIM=$FRE_LYR$FRE_LMH$FRE_LDY'T'$FRE_LHR$FRE_MN'00WST'
		
	FRE_FPATH=$SPATH'FRE/'$FRE_YR'/'$FRE_MH'/'$FRE_DY'/'
		
	LTPATH=$LPATH'/'$FRE_LYR'/'$FRE_LMH'/'$FRE_LDY'/'
	SITEFILE=$OPATH'rotswimsite.dat'
	
	FRE_LNAME='_FRE_5min_avg'
	FRE_EPSFILE=$TPATH$FRE_LDATTIM$FRE_LNAME$pend
	FRE_PNGFILE=$LTPATH$LDATTIM$FRE_LNAME$eend
	FRE_NCFILE=$TPATH$FRE_DATTIM$FRE_LNAME$nend
	FRE_FNAME='IMOS_ACORN_RV_'$FRE_DATTIM'_FRE'$FEND
		
	# and then Guilderton's previous one
	GUI_DATLAB=$GUI_DY"/"$GUI_MH"/"$GUI_YR
	GUI_DATTIM=$GUI_YR$GUI_MH$GUI_DY'T'$GUI_HR$GUI_MN'00Z'
	GUI_LDATTIM=$GUI_LYR$GUI_LMH$GUI_LDY'T'$GUI_LHR$GUI_MN'00WST'
		
	GUI_FPATH=$SPATH'GUI/'$GUI_YR'/'$GUI_MH'/'$GUI_DY'/'
		
	GUI_LNAME='_GUI_5min_avg'
	GUI_EPSFILE=$TPATH$GUI_LDATTIM$GUI_LNAME$pend
	GUI_PNGFILE=$LTPATH$LDATTIM$GUI_LNAME$eend
	GUI_NCFILE=$TPATH$GUI_DATTIM$GUI_LNAME$nend
	GUI_FNAME='IMOS_ACORN_RV_'$GUI_DATTIM'_GUI'$FEND

	# check the Fremantle's file
	if test -e $FRE_FPATH$FRE_FNAME
	then
		# check the Guilderton's file
		if test -e $GUI_FPATH$GUI_FNAME
		then
			# check for a POSITION dimension
			isFRE_POSITION=`ncdump -h $FRE_FPATH$FRE_FNAME | grep -E -i "POSITION = "`
			isGUI_POSITION=`ncdump -h $GUI_FPATH$GUI_FNAME | grep -E -i "POSITION = "`
			if [ ! -z "$isFRE_POSITION" ]
			then # isFRE_POSITION is not empty
				if [ ! -z "$isGUI_POSITION" ]
				then # isGUI_POSITION is not empty
					echo 'FRE '$FRE_DATTIM
					echo 'GUI '$GUI_DATTIM
			
					if test $isFirst -eq 1
					then
						echo $FRE_CURDATESEC > $OPATH'last_10min_rot.txt'
						isFirst=0
					fi
			
					mkdir -p $LTPATH
					mkdir -p $TPATH
				
					# we start with Fremantle
					cp -p $FRE_FPATH$FRE_FNAME $FRE_NCFILE
				
					ncks -H -v LATITUDE -s "\n%f" -C  $FRE_NCFILE > $TPATH'FRE_LATITUDE.txt'
					ncks -H -v LONGITUDE -s "\n%f" -C  $FRE_NCFILE > $TPATH'FRE_LONGITUDE.txt'
					ncks -H -v ssr_Surface_Radial_Sea_Water_Speed -s "\n%f" -C  $FRE_NCFILE > $TPATH'FRE_RADIALS.txt'
					ncks -H -v ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity -s "\n%f" -C  $FRE_NCFILE > $TPATH'FRE_RADIALD.txt'
					ncks -H -v POSITION -s "\n%u" -C  $FRE_NCFILE > $TPATH'FRE_POSITION.txt'
				
					paste $TPATH'FRE_POSITION.txt' $TPATH'FRE_LONGITUDE.txt' $TPATH'FRE_LATITUDE.txt' $TPATH'FRE_RADIALS.txt' $TPATH'FRE_RADIALD.txt' > $TPATH'RADIALSFRE.xyz'
				
					# we continue with Guilderton
					cp -p $GUI_FPATH$GUI_FNAME $GUI_NCFILE
			
					ncks -H -v LATITUDE -s "\n%f" -C  $GUI_NCFILE > $TPATH'GUI_LATITUDE.txt'
					ncks -H -v LONGITUDE -s "\n%f" -C  $GUI_NCFILE > $TPATH'GUI_LONGITUDE.txt'
					ncks -H -v ssr_Surface_Radial_Sea_Water_Speed -s "\n%f" -C  $GUI_NCFILE > $TPATH'GUI_RADIALS.txt'
					ncks -H -v ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity -s "\n%f" -C  $GUI_NCFILE > $TPATH'GUI_RADIALD.txt'
					ncks -H -v POSITION -s "\n%u" -C  $GUI_NCFILE > $TPATH'GUI_POSITION.txt'
				
					paste $TPATH'GUI_POSITION.txt' $TPATH'GUI_LONGITUDE.txt' $TPATH'GUI_LATITUDE.txt' $TPATH'GUI_RADIALS.txt' $TPATH'GUI_RADIALD.txt' > $TPATH'RADIALSGUI.xyz'
				
					# generate combined vectorised xyz files for SPEED, U and V of site ROT
					perl $OPATH'rad2vec.pl' $TPATH
				
				
					CPTFILE=$OPATH'10min_rot.cpt'
			
					# set the defaults. I find that the GMT default values for these
					# (ie Helvetica and LARGE) seem to shout too loud 
					GMT gmtset DOTS_PR_INCH 600
					GMT gmtset ANOT_FONT Times-Roman
					GMT gmtset ANOT_FONT_SIZE 12
					GMT gmtset LABEL_FONT Times-Roman
					GMT gmtset LABEL_FONT_SIZE 15
					GMT gmtset HEADER_FONT Times-Roman
					GMT gmtset HEADER_FONT_SIZE 15
					GMT gmtset HEADER_OFFSET 0.05c
					GMT gmtset BASEMAP_TYPE FANCY
					GMT gmtset FRAME_WIDTH 0.15
		
					# make the colour palette
					GMT makecpt -Cjet $CSCLV -Z > $CPTFILE
	
					SF=$TPATH'S.grd'
					UF=$TPATH'U.grd'
					VF=$TPATH'V.grd'
	
					GMT xyz2grd $TPATH'SPEED.xyz' -G$SF -H1 -I$SAMP ${VERBOSE} ${RANGE} 
					GMT xyz2grd $TPATH'U.xyz' -G$UF -H1 -I$SAMP ${VERBOSE} ${RANGE} 
					GMT xyz2grd $TPATH'V.xyz' -G$VF -H1 -I$SAMP ${VERBOSE} ${RANGE} 
	
					LNAME='_ROT_10min_avg'
					EPSFILE=$TPATH$FRE_LDATTIM$LNAME$pend
					PNGFILE=$LTPATH$FRE_LDATTIM$LNAME$eend
					NCFILE=$TPATH$FRE_DATTIM$LNAME$nend
	
					# coastal reatures
					RIVERS=-Ia
					DRY=-G${LAND_COLOUR}
					WET=-S${SEA_COLOUR}
					COASTPEN=-W3

					#GMT pscoast $OPTS -P $RES $DRY $COASTPEN -K > $EPSFILE
					GMT pscoast $OPTS -P $RES $DRY $COASTPEN -Y4 -K > $EPSFILE

					GMT grdimage $SF -C$CPTFILE $OPTS -P -Q -O -K >> $EPSFILE
		
					#plot  arrows with arrowwidth/headlength/headwidth
					GMT grdvector $UF $VF $OPTS -P -Gblack $VSCAL -E -O -K >> $EPSFILE
					GMT pscoast $OPTS -P $RES $DRY $COASTPEN -K -O >> $EPSFILE
					GMT pstext $SITEFILE $OPTS -P  -O -K >> $EPSFILE
					GMT psxy $SITEFILE $OPTS -P -Sd0.2c -Gred -O -K >> $EPSFILE
	
					# plot the basemap
					#ANNOTE=-B0.5g0.5:."$FRE_DATLAB@@$FRE_HR\072$FRE_MN": # annotation interval/g/line interval
					ANNOTE=-Bf0.05g0.05/f0.05g0.05:."$FRE_LYR-$FRE_LMH-$FRE_LDY@@$FRE_LHR\072$FRE_MN\000WST": # annotation interval/g/line interval
					GMT psbasemap $OPTS -P $ANNOTE $SCALE -U -O -K >> $EPSFILE
	
					# add colour scale
					#GMT psscale -D3.6i/3.9i/2.2i/0.1i -C$CPTFILE -O >> $EPSFILE
					GMT psscale -D1.79i/-0.4i/3.7i/0.1ih -B0.1:"Current speed (m/s)": -C$CPTFILE -O >> $EPSFILE
	
					# create png file
					GMT ps2raster -Au -Tg $EPSFILE -D$LTPATH
				fi
			fi
		fi
	fi
		
	# then let's de-crement the dates from 10min
	FRE_CURDATESEC=`echo $FRE_CURDATESEC' - 60 * 10' | bc`
	FRE_CURDATESTR=`date -u -d @$FRE_CURDATESEC +%Y-%m-%dT%H:%M:00Z`
	FRE_YR=`date -u -d $FRE_CURDATESTR +%Y`
	FRE_MH=`date -u -d $FRE_CURDATESTR +%m`
	FRE_DY=`date -u -d $FRE_CURDATESTR +%d`
	FRE_HR=`date -u -d $FRE_CURDATESTR +%H`
	FRE_MN=`date -u -d $FRE_CURDATESTR +%M`

	FRE_LYR=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%Y`
	FRE_LMH=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%m`
	FRE_LDY=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%d`
	FRE_LHR=`TZ='Australia/Perth' date -d $FRE_CURDATESTR +%H`

	GUI_CURDATESEC=`echo $GUI_CURDATESEC' - 60 * 10' | bc`
	GUI_CURDATESTR=`date -u -d @$GUI_CURDATESEC +%Y-%m-%dT%H:%M:00Z`
	GUI_YR=`date -u -d $GUI_CURDATESTR +%Y`
	GUI_MH=`date -u -d $GUI_CURDATESTR +%m`
	GUI_DY=`date -u -d $GUI_CURDATESTR +%d`
	GUI_HR=`date -u -d $GUI_CURDATESTR +%H`
	GUI_MN=`date -u -d $GUI_CURDATESTR +%M`

	GUI_LYR=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%Y`
	GUI_LMH=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%m`
	GUI_LDY=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%d`
	GUI_LHR=`TZ='Australia/Perth' date -d $GUI_CURDATESTR +%H`
done

rm -rf $TPATH
