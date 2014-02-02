#! /bin/sh
#
#
#  ACORN most recent hourly averaged current plots from netcdf files
#  downloaded from THREDDS server
#
# Author : Guillaume Galibert (from Lucy Wyatt model)
#
# to run ./rotswim-hourmap.sh 
# 
# 

#VERBOSE=-V
MN='30'
CURDATESTR=`date -u +%Y-%m-%dT%H:$MN:00Z`
CURDATESEC=`date -u -d $CURDATESTR +%s`
YR=`date -u -d $CURDATESTR +%Y`
MH=`date -u -d $CURDATESTR +%m`
DY=`date -u -d $CURDATESTR +%d`
HR=`date -u -d $CURDATESTR +%H`

LYR=`TZ='Australia/Perth' date -d $CURDATESTR +%Y`
LMH=`TZ='Australia/Perth' date -d $CURDATESTR +%m`
LDY=`TZ='Australia/Perth' date -d $CURDATESTR +%d`
LHR=`TZ='Australia/Perth' date -d $CURDATESTR +%H`
	
NUC='ROT'
NLC="rot"
	
# plot range
# for rot
#WIDTH=-Jm1:1000000
WIDTH=-Jm1:400000
#RANGE="-R115/116./-32.5/-31.5"
RANGE="-R115.42/115.75/-32.08/-31.92"
		
# grid sampling
# every third replaced with every second
SAMP="-I2.9684m,4.4367m"
		
# vector scaling
#VSCAL="-Q0.1c/0.8c/0.4cn3"
VSCAL="-Q0.1c/1c/0.5cn3"
		
# colour coding
CSCL="-T0/0.5/0.05"
		
# scale location
#SCALE="-L115.6/-32.38/-32/10" 	# long/lat of scale centre/lat of scaling/length
SCALE="-L115.69/-31.925/-32/10"

# rest is site independent
SPATH=$OPENDAP'/ACORN/gridded_1h-avg-current-map_non-QC/'
FEND='_FV00_1-hour-avg.nc'
	
RES=-Df
SEA_COLOUR=220/220/255
LAND_COLOUR=220/255/220
RADAR_COLOUR=255/0/0
WIND2_COLOUR=0/0/255
WIND1_COLOUR=255/0/0
	
OPATH=$ACORN_EXP'/GMT/'
LPATH=$OPENDAP'/../public/ACORN/Rottnest_swim/60min_avg/'
LNAME='_ROT_60min_avg'
nend='.nc'
pend='.ps'
eend='.png'

# don't change this.
OPTS="${VERBOSE} ${RANGE} ${WIDTH}"

LASTDATESEC=`cat $OPATH'last_60min_rot.txt'`

echo 'Plot latest 60min averaged ROT files :'

isFirst=1
while test $CURDATESEC -ge $LASTDATESEC
do
	# want to search backwards in time to find latest files on the system
	# will stop when reaches last generated plot

	# from here is date specific
	DATLAB=$DY"/"$MH"/"$YR
	DATTIM=$YR$MH$DY'T'$HR$MN'00Z'
	LDATTIM=$LYR$LMH$LDY'T'$LHR$MN'00WST'
	FPATH=$SPATH$NUC'/'$YR'/'$MH'/'$DY'/'

	# files
	LTPATH=$LPATH'/'$LYR'/'$LMH'/'$LDY'/'
	TPATH='/tmp/'$$'/'
	
	EPSFILE=$TPATH$LDATTIM$LNAME$pend
	PNGFILE=$LTPATH$LDATTIM$LNAME$eend
	NCFILE=$TPATH$DATTIM$LNAME$nend
	SITEFILE=$OPATH$NLC'swimsite.dat'
	FNAME='IMOS_ACORN_V_'$DATTIM'_'$NUC$FEND
	
	# check the file
	if test -e $FPATH$FNAME
	then		
		echo $DATTIM
		
		if test $isFirst -eq 1
		then
			echo $CURDATESEC > $OPATH'last_60min_rot.txt'
			isFirst=0
		fi
		
		mkdir -p $LTPATH
		mkdir -p $TPATH
		cp -p $FPATH$FNAME $NCFILE

		DATA='SPEED'
		U='UCUR'
		V='VCUR'
		
		DATAFILE="$NCFILE?$DATA"
		UF="$NCFILE?$U"
		VF="$NCFILE?$V"
		
		CPTFILE=$OPATH'60min_rot.cpt'

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
		GMT makecpt -Cjet -Z $CSCL  > $CPTFILE

		# coastal features
		RIVERS=-Ia
		DRY=-G${LAND_COLOUR}
		WET=-S${SEA_COLOUR}
		COASTPEN=-W3
		
		#GMT pscoast $OPTS -P $RES $RIVERS $DRY $WET $COASTPEN -K > $EPSFILE
		GMT pscoast $OPTS -P $RES $DRY $COASTPEN -Y4 -K > $EPSFILE

		GMT grdimage $DATAFILE -C$CPTFILE $OPTS -P -Q -O -K >> $EPSFILE

		#plot  arrows with arrowwidth/headlength/headwidth
		GMT grdvector $UF $VF $OPTS -P -Gblack $VSCAL $SAMP -S0.5 -E -O -K >> $EPSFILE
		GMT pscoast $OPTS -P $RES $DRY $COASTPEN -K -O >> $EPSFILE
		GMT pstext $SITEFILE $OPTS -P -O -K >> $EPSFILE
		GMT psxy $SITEFILE $OPTS -P -Sd0.2c -Gred -O -K >> $EPSFILE
 
		# plot the basemap
		#ANNOTE=-B0.5g0.5:."$DATLAB@@$HR\072$MN\000UTC": # annotation interval/g/line interval
		ANNOTE=-Bf0.05g0.05/f0.05g0.05:."$LYR-$LMH-$LDY@@$LHR\072$MN\000WST": # annotation interval/g/line interval
		#ANNOTE=-B:."$LYR-$LMH-$LDY@@$LHR\072$MN\000WST": # annotation interval/g/line interval
		GMT psbasemap $OPTS -P $ANNOTE $SCALE -U -O -K >> $EPSFILE
 
		# add colour scale
		#GMT psscale -D3.6i/3.9i/2.2i/0.1i -C$CPTFILE -O >> $EPSFILE
		GMT psscale -D1.79i/-0.4i/3.7i/0.1ih -B0.1:"Current speed (m/s)": -C$CPTFILE -O >> $EPSFILE

		# create png file
		GMT ps2raster -Au -Tg $EPSFILE -D$LTPATH
	fi
	
	# we de-cremente 1hour and apply this to the whole UTC date
  CURDATESEC=`expr $CURDATESEC - 3600`
	CURDATESTR=`date -u -d @$CURDATESEC +%Y-%m-%dT%H:$MN:00Z`

	# we update the UTC and local time variables
	YR=`date -u -d $CURDATESTR +%Y`
	MH=`date -u -d $CURDATESTR +%m`
	DY=`date -u -d $CURDATESTR +%d`
	HR=`date -u -d $CURDATESTR +%H`

	LYR=`TZ='Australia/Perth' date -d $CURDATESTR +%Y`
	LMH=`TZ='Australia/Perth' date -d $CURDATESTR +%m`
	LDY=`TZ='Australia/Perth' date -d $CURDATESTR +%d`
	LHR=`TZ='Australia/Perth' date -d $CURDATESTR +%H`
done

rm -rf $TPATH
