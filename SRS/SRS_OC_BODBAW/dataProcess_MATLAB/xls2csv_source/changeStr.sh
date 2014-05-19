#!/bin/bash
OLD="xls2csv"
NEW="xls2csv_PERL"
DPATH="/home/lbesnard/Desktop/xls2csv-1.07/"
BPATH="/home/lbesnard/Desktop/bakup/foo"
TFILE="/tmp/out.tmp.$$"
[ ! -d $BPATH ] && mkdir -p $BPATH || :
#for f in $DPATH
#do
#echo $f
#  if [ -f $f -a -r $f ]; then
#    /bin/cp -f $f $BPATH
#   sed "s/$OLD/$NEW/g" "$f" > $TFILE && mv $TFILE "$f"
#  else
#   echo "Error: Cannot read $f"
#  fi
#done
cd $DPATH

for f in `find . -name \*`
do
echo $f
  if [ -f $f -a -r $f ]; then
    /bin/cp -f $f $BPATH
   sed "s/$OLD/$NEW/g" "$f" > $TFILE && mv $TFILE "$f"
  else
   echo "Error: Cannot read $f"

 fi
done
