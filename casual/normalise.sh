#! /bin/sh
# Takes a pagesize and a postscript file, and alters it to fit neatly
# in 1 page.

# Based on posterize by Rusty Russell (c) 2001.  GPL.

# 3% margins except for left margin which is 7% to accomodate punched holes
DEFAULT_MARGIN=0.03
WIDE_MARGIN=0.07

printusage()
{
    echo "$@" >&2
    echo "Usage: `basename $0` [--norotate] <papersize> <filename>..." >&2
    echo "    Makes the file fit on the paper." >&2
    exit 1
}

[ "$#" -lt 2 ] && printusage "Require two or more arguments."

if [ "$1" == "--norotate" ]; then
    shift
else
    ROTATE=1
fi

case "$1" in
    letter) PAPER_WIDTH=612; PAPER_HEIGHT=792;;
    a4) PAPER_WIDTH=595; PAPER_HEIGHT=842;;
    a3) PAPER_WIDTH=842; PAPER_HEIGHT=1190;;
    a0) PAPER_WIDTH=2384; PAPER_HEIGHT=3370;;
    11x17) PAPER_WIDTH=792; PAPER_HEIGHT=1224;;
    poster) PAPER_WIDTH=3024; PAPER_HEIGHT=4000; DISTORT=1;;
    # Add your paper here...
    *) printusage "Unknown papersize $1.  Change, or edit script.";;
esac

# Switch paper width and height
if [ -n "$ROTATE" ]; then
    TMP=$PAPER_HEIGHT
    PAPER_HEIGHT=$PAPER_WIDTH
    PAPER_WIDTH=$TMP
fi

echo
shift
FILE_IX=0
for FILE; do
     FILENAME[$FILE_IX]=$FILE

#    BBOX=`gs -sPAPERSIZE=a0 -sDEVICE=bbox < $FILE 2>&1 >/dev/null | grep '^%%BoundingBox' | cut -d: -f2`
     BBOX=`(echo a3 0.02 0.02 scale; echo 4000 4000 translate; cat $FILE) | gs -sDEVICE=bbox 2>&1 >/dev/null | grep '^%%HiResBoundingBox' | cut -d: -f2`
    BBOX_X_MIN[$FILE_IX]=`echo $BBOX | cut -d\  -f1`
    BBOX_Y_MIN[$FILE_IX]=`echo $BBOX | cut -d\  -f2`
    BBOX_X_MAX[$FILE_IX]=`echo $BBOX | cut -d\  -f3`
    BBOX_Y_MAX[$FILE_IX]=`echo $BBOX | cut -d\  -f4`


    if [ -z ${BBOX_X_MIN[$FILE_IX]} ]; then
	   echo "FATAL: Bounding Box Calculation failed for $FILE!"
	   exit 1
    fi

#echo "BBOX_X_MIN: $BBOX_X_MIN BBOX_Y_MIN: $BBOX_Y_MIN BBOX_X_MAX: $BBOX_X_MAX BBOX_Y_MAX: $BBOX_Y_MAX"

#Adjust for previous scaling
BBOX_X_MIN[$FILE_IX]=`echo ${BBOX_X_MIN[$FILE_IX]} \* 50 - 4000 | bc`
BBOX_Y_MIN[$FILE_IX]=`echo ${BBOX_Y_MIN[$FILE_IX]} \* 50 - 4000 | bc`
BBOX_X_MAX[$FILE_IX]=`echo ${BBOX_X_MAX[$FILE_IX]} \* 50 - 4000 | bc`
BBOX_Y_MAX[$FILE_IX]=`echo ${BBOX_Y_MAX[$FILE_IX]} \* 50 - 4000 | bc`

#echo "BBOX_X_MIN: $BBOX_X_MIN BBOX_Y_MIN: $BBOX_Y_MIN BBOX_X_MAX: $BBOX_X_MAX BBOX_Y_MAX: $BBOX_Y_MAX"

    WIDTH[$FILE_IX]=`echo scale=5\; ${BBOX_X_MAX[$FILE_IX]} \- ${BBOX_X_MIN[$FILE_IX]} | bc`
    HEIGHT[$FILE_IX]=`echo scale=5\; ${BBOX_Y_MAX[$FILE_IX]} \- ${BBOX_Y_MIN[$FILE_IX]} | bc`

    TOTAL_WIDTH=`echo scale=5\; $PAPER_WIDTH \* \(1.0000 \- $DEFAULT_MARGIN \- $WIDE_MARGIN \) | bc`
    TOTAL_HEIGHT=`echo scale=5\; $PAPER_HEIGHT \* \(1.0000 \- $DEFAULT_MARGIN \* 2 \) | bc`

    LEFT_MARGIN=`echo $PAPER_WIDTH \* $WIDE_MARGIN | bc`
    BOTTOM_MARGIN=`echo $PAPER_HEIGHT \* $DEFAULT_MARGIN | bc`

    HEIGHT_SCALE[$FILE_IX]=`echo scale=5\; $TOTAL_HEIGHT \/ ${HEIGHT[$FILE_IX]} | bc`
    WIDTH_SCALE[$FILE_IX]=`echo scale=5\; $TOTAL_WIDTH \/ ${WIDTH[$FILE_IX]} | bc`

# fit page to width
# NOTE: PAGE MAY NOT NOW FIT ONE PAGE
#       WE MUST 'translate' THE POSTSCRIPT ITERATIVELY on Y-AXIS to 
#       SHIFT THE VISIBLE PRINTING AREA DOWN THROUGH EACH PAGE

     HEIGHT_SCALE[$FILE_IX]=${WIDTH_SCALE[$FILE_IX]}

     let FILE_IX++
done
# choose the smallest scale and scale all files to this scale
LEAST_SCALE_IX=0
for (( IX=0; IX < FILE_IX ; IX++ )) ; do
#   echo "considering table$((${IX}+1)).ps, SCALE =  ${HEIGHT_SCALE[$IX]} "
    if [ `echo ${HEIGHT_SCALE[$IX]} \< ${HEIGHT_SCALE[LEAST_SCALE_IX]} | bc` = 1 ]; 
    then
        LEAST_SCALE_IX=$IX
    fi
done 

#   echo "LEAST_SCALE from table$((${LEAST_SCALE_IX}+1)).ps and is  ${HEIGHT_SCALE[LEAST_SCALE_IX]}"

for (( IX=0; IX < FILE_IX;  IX++ )) ; do
    FILE=${FILENAME[$IX]}
    # Find end of preamble.
    if ! mv $FILE $FILE.old
    then
	echo Can\'t move file $FILE out the way >&2
  	exit 1
    fi

#    echo "HEIGHT: ${HEIGHT[$IX]} ,ph:$PAPER_HEIGHT"

    # SIMULATE 'repeat ... until' i.e. Loop at least ONCE to print at least one page
    #	when Y_LIMIT starts out less than Y_TRANSLATE 
    Y_LIMIT=1
    Y_TRANSLATE=0
    PAGE=1

    # Iterate until we have printed everything in the bounding box
    while [ `echo \($Y_TRANSLATE \< $Y_LIMIT\)  | bc` = 1 ]; do
    # initialise 'until' variables
	if [ $Y_LIMIT == 1 ]; 
	then
#		echo "INIT Y_LIMIT & Y_TRANSLATE"
		Y_TRANSLATE=`echo \(${BBOX_Y_MAX[$IX]} \* -1 \+ \($TOTAL_HEIGHT \/ ${HEIGHT_SCALE[LEAST_SCALE_IX]}\)\) | bc`
		Y_LIMIT=`echo $Y_TRANSLATE \+ ${HEIGHT[$IX]} | bc`
				
	fi
#	echo "Y_LIMIT $Y_LIMIT,  Y_TRANSLATE $Y_TRANSLATE "
	echo "FILE: $FILE, Page: $PAGE"

	PREAMB_END=`grep -n '^%%EndProlog$' < $FILE.old | head -1 | cut -d: -f1`
	head -$(($PREAMB_END-1)) $FILE.old > $FILE

	if [ -n "$ROTATE" ]; then
	    # Shift across, then rotate 90 anticlockwise.
	    echo "$PAPER_HEIGHT 0 translate" >> $FILE
	    echo "90 rotate" >> $FILE
	fi
	echo "$LEFT_MARGIN $BOTTOM_MARGIN translate" >> $FILE
	echo "${WIDTH_SCALE[$LEAST_SCALE_IX]} ${HEIGHT_SCALE[$LEAST_SCALE_IX]} scale" >> $FILE
	echo ${BBOX_X_MIN[$IX]} \* -1 | bc >> $FILE
	echo $Y_TRANSLATE >> $FILE
	echo "translate" >> $FILE

	tail +$PREAMB_END $FILE.old >> $FILE
  	# Force printer eject by appending a '^D' character
	echo -e "\004" >> $FILE
	
 
# OK! $FILE is now positioned to print the next page of the scrutiny sheet.
# 
# copy this version of the file to a new filename just for this page
	cp $FILE "${FILE}.${PAGE}"

# restore the original file ready for the next page 
 	cp $FILE.old $FILE

# update the y-axis coord for the next page
	Y_TRANSLATE=`echo  $TOTAL_HEIGHT \/ ${HEIGHT_SCALE[$LEAST_SCALE_IX]} \+ $Y_TRANSLATE  | bc`

	let PAGE++

    done
#    echo "$FILE complete"
    rm -f $FILE.old

done

exit 0

