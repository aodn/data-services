#! /bin/sh
#
#
#  ACORN most recent vector current plots from netcdf files
#  downloaded from THREDDS server
#
# Author : Guillaume Galibert (from Lucy Whyatt model)
#
# to run ./rot-currentmap.sh 
# 
# 

#VERBOSE=-V
YR=`date +%Y`
MH=`date +%m`
DY=`date +%d`
HR=`date +%H`
MN='30'
	
NUC='ROT'
NLC="rot"
	
# plot range
# for rot
WIDTH=-Jm1:1000000
RANGE="-R115/116./-32.5/-31.5"
		
# grid sampling
# grid spacing for cof is 1.48419/1.71838 I have put arrows with 3 cell spacing
# seems to work for cbg too?
SAMP="4.4526m,5.1551m"
# every third replaced with every second
SAMP="2.9684m,4.4367m"
		
# vector scaling
VSCAL="-Q0.1c/0.8c/0.4cn3" 
		
# colour coding
CSCL="-T0/0.5/0.05"
		
# scale location
SCALE="-L115.6/-32.38/-32/10" 	# long/lat of scale centre/lat of scaling/length
		
# map title
tinf="115.45 -32.45 15 0 1 LT "


# rest is site independent
SPATH=$OPENDAP'/ACORN/gridded_1h-avg-current-map_non-QC/'
FEND='_FV00_1-hour-avg.nc'
	
RES=-Di
SEA_COLOUR=220/220/255
LAND_COLOUR=220/255/220
RADAR_COLOUR=255/0/0
WIND2_COLOUR=0/0/255
WIND1_COLOUR=255/0/0
	
OPATH=$ACORN_EXP'/GMT/'
LPATH=$OPENDAP'/ACORN/Rottnest_swim/'
LNAME='latest_60min_averaged'
nend='.nc'
pend='.ps'
eend='.png'

# don't change this.
OPTS="${VERBOSE} ${RANGE} ${WIDTH}"
wchk='n'
#ct=1
	
while test $wchk = 'n'
do
	# want to search backwards in time to find latest file on the system
	# will stop if nothing more recent than 2006 is found
	if test $YR -gt 2006
	then
		# from here is date specific
		DATLAB=$DY"/"$MH"/"$YR
		DATTIM=$YR$MH$DY'T'$HR$MN'00'
		FPATH=$SPATH$NUC'/'$YR'/'$MH'/'$DY'/'

		# files
		EPSFILE=$LPATH$LNAME$pend
		epsfile=$LPATH$LNAME$eend
		SITEFILE=$OPATH$NLC'site.dat'
		FNAME='IMOS_ACORN_V_'$DATTIM'Z_'$NUC$FEND
		
		# check the file
		if test -e $FPATH$FNAME
		then
			echo $DATTIM
			cp -p $FPATH$FNAME $LPATH$LNAME$nend
			wchk='y'
			title=$tinf$DATLAB@@$HR":"$MN" UTC"
			echo $title > TITFILE
			DATA='SPEED'
			DATAFILE="$LPATH$LNAME$nend?$DATA"
			U='UCUR'
			V='VCUR'
			UF="$LPATH$LNAME$nend?$U"
			VF="$LPATH$LNAME$nend?$V"
			CPTFILE=$OPATH'acorn.cpt'

			# set the defaults. I find that the GMT default values for these
			# (ie Helvetica and LARGE) seem to shout too loud 
			GMT gmtset DOTS_PR_INCH 600
			GMT gmtset ANOT_FONT Times-Roman
			GMT gmtset ANOT_FONT_SIZE 12
			GMT gmtset LABEL_FONT Times-Roman
			GMT gmtset LABEL_FONT_SIZE 17
			GMT gmtset HEADER_FONT Times-Roman
			GMT gmtset HEADER_FONT_SIZE 24
			GMT gmtset BASEMAP_TYPE FANCY
			GMT gmtset FRAME_WIDTH 0.15

			# make the colour palette
			GMT makecpt -Cjet $CSCL  > $CPTFILE

			# remove the previous version of the picture
			rm -f $EPSFILE

			# coastal features
			RIVERS=-Ia
			DRY=-G${LAND_COLOUR}
			WET=-S${SEA_COLOUR}
			COASTPEN=-W3
			GMT pscoast $OPTS -P $RES $RIVERS $DRY $WET $COASTPEN -K > $EPSFILE
			GMT pscoast $OPTS -P $RES $DRY $COASTPEN -K > $EPSFILE

			GMT grdimage  $DATAFILE -C$CPTFILE $OPTS -P -Q -O -K >> $EPSFILE

			#plot  arrows with arrowwidth/headlength/headwidth
			GMT grdvector $UF $VF $OPTS -P -Gblack $VSCAL -I$SAMP -E -O -K >> $EPSFILE
			GMT pscoast $OPTS -P $RES $DRY $COASTPEN -K -O >> $EPSFILE
			GMT pstext $SITEFILE $OPTS -P  -O -K >>$EPSFILE
			GMT pstext TITFILE $OPTS -P  -O -K >>$EPSFILE
			GMT psxy $SITEFILE $OPTS -P -Sd0.4c -Gred -O -K >>$EPSFILE
 
			# plot the basemap
			ANNOTE=-B0.5g0.5:."$DATLAB@@$HR\072$MN": # annotation interval/g/line interval
			GMT psbasemap $OPTS -P $ANNOTE $SCALE -U -O -K >> $EPSFILE
 
			# add colour scale
			GMT psscale -D3.6i/3.9i/2.2i/0.1i -C$CPTFILE -O >> $EPSFILE

			# create png/eps file
			GMT ps2raster -Au -Tg $EPSFILE
			GMT ps2raster -Au -Te $EPSFILE

			# have a look at the result
			\rm $EPSFILE

		fi
		if test $wchk = 'n'
		then
	    HR=`expr $HR - 1`
	    if test $HR -eq 0
	    then 
				HR=23
				DY=`expr $DY - 1`
				if test $DY -eq 0
				then
			    DY=31
			    MH=`expr $MH - 1`
			    if test $MH -eq 0
			    then
						MH=12
						YR=`expr $YR - 1`
			    fi
			    if test $MH -lt 10
			    then
						MH='0'$MH
			    fi
				fi
				if test $DY -lt 10
				then
		     DY='0'$DY
				fi
	    fi
	    if test $HR -lt 10
	    then
				HR='0'$HR
	    fi
    fi
  else
  	# we need to get out of this infinite loop in case no file is found
  	wchk='y'
	fi
done
