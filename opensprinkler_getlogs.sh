#~/bin/bash

# Saxon Mailey 2014
# saxon at scm dot id dot au

LOGDIR=~/log
LOGEXT='csv'
KEEPLOG=0
if [ ! -d $LOGDIR ];then mkdir $LOGDIR; fi
TMPFILE="/tmp/$$.tmp"
BASEURL='http://mailey.net.au/os/log.php'
DATESPEC="`date +%Y-%m-%d`"

if [ -z PS1 ];then
	DEBUG=0
else
	DEBUG=1
fi

# FUNCTIONS --------------------------------------------------------------------

function publish {
	if [ $DEBUG -gt 0 ];then
		echo "Publishing $1 to $BASEURL"
		echo '(. = record updated, x = record uploaded previously)'
	fi
	if [ -f $1 ];then
		declare -a LOGDATA=(`cat $1|grep -v [a-z]`)
		IFS=$','
		for LOGENTRY in "${LOGDATA[@]}"
		do
			declare -a LOGELEMENT=($LOGENTRY)
			local PROGRAM="${LOGELEMENT[0]}"
			local STATION="${LOGELEMENT[1]}"
			local RUNTIME="${LOGELEMENT[2]}"
			local LOGTIME="${LOGELEMENT[3]}"
			URL="${BASEURL}?host=${OSHOST}&time=${LOGTIME}&program=${PROGRAM}&station=${STATION}&runtime=${RUNTIME}&tz=0"
			if [ $DEBUG -gt 1 ];then
				echo "$URL"
			fi
			RC=`curl --silent --show-error "$URL"`
			if [ "$RC" == '1' ];then
				echo -n '.'
			else
				echo "curl: ERROR ($RC) when trying to get $URL"
			fi
		done
		echo ""
		unset IFS
	fi
}

function processfile {
	local FILEIN=$1
	local FILEOUT=$2
	if [ $DEBUG -gt 0 ];then
		echo "Processing Logs"
		echo ""
	fi
	echo '"Program","Station","Time (sec)","Date (epoc)"' > $FILEOUT
	cat $FILEIN | sed "s/\]\,\[/\n/g" | sed 's/\[\[//g' | sed 's/\]\]//g' >> $FILEOUT
	echo "" >> $FILEOUT
	publish $FILEOUT
}

function getlogs {
	local UTSTART="`date --date=\"$DATESTART\" +%s`"
	local UTEND="`date   --date=\"$DATEEND\"   +%s`"
	local URL="http://$OSHOST/jl?pw=$OSPASS&start=$UTSTART&end=$UTEND"
	
	if [ $DEBUG -gt 0 ];then
		echo "Getting Logs"
		echo " - Host:  $1"
		echo " - Start: $3 ($UTSTART)"
		echo " - End:   $4 ($UTEND)"
		echo " - Log:   $5"
		echo " - Dat:   $TMPFILE"
		echo ""
	fi
	curl --silent --show-error "$URL" > $TMPFILE
	if [ $? -ne 0 ];then
		echo "curl: $URL"
	else
		CHARS=`cat $TMPFILE|wc -c`
		if [ $CHARS -lt 15 ]; then
			echo "WARNING: No Records Found"
		else
			processfile $TMPFILE $LOGFILE
		fi
	fi

}

# MAIN PROGRAM -----------------------------------------------------------------
	
if [ $# -lt 2 ];then
	echo "$0 <opensprinkler hostname> <password> [today(default)/yesterdy/thismonth/lastmonth/date] [date (yyyy-mm-dd)]"
	exit 1
else
	OSHOST="`getent hosts $1 | awk '{print $2}'`"
	if [ "$OSHOST" == '' ];then
		OSHOST="$1"
	fi
	OSPASS="$2"
	if [ $# -lt 3 ];then
		DATESPEC='today'
	else
		if [ "$3" != '' ];then
			DATESPEC="$3"
		fi
	fi
fi

case $DATESPEC in
"today")
	DATESTART="`date --date=today     \"+%Y-%m-%d 00:00:00 +00:00\"`"
	DATEEND="`date   --date=today     \"+%Y-%m-%d 23:59:59 +00:00\"`"
	LOGDATE="`date   --date=today     \"+%Y%m%d\"`"
	;;
"yesterday")
	DATESTART="`date --date=yesterday \"+%Y-%m-%d 00:00:00 +00:00\"`"
	DATEEND="`date   --date=today     \"+%Y-%m-%d 00:00:00 +00:00\"`"
	LOGDATE="`date   --date=yesterday \"+%Y%m%d\"`"
	;;
"thismonth")
	DATESTART="`date --date=today     \"+%Y-%m-01 00:00:00 +00:00\"`"
	DATEEND="`date   --date=today     \"+%Y-%m-%d 23:59:59 +00:00\"`"
	LOGDATE="`date   --date=today     \"+%Y%m\"`"
	;;
"lastmonth" | "1monthago")
	DATESTART="`date --date=\"last month\" \"+%Y-%m-01 00:00:00 +00:00\"`"
	DATEEND="`date   --date=today        \"+%Y-%m-01 00:00:00 +00:00\"`"
	LOGDATE="`date   --date=\"last month\" \"+%Y%m\"`"
	;;
"2monthsago")
	DATESTART="`date --date=\"2 months ago\" \"+%Y-%m-01 00:00:00 +00:00\"`"
	DATEEND="`date   --date=\"1 month ago\"  \"+%Y-%m-01 00:00:00 +00:00\"`"
	LOGDATE="`date   --date=\"2 months ago\" \"+%Y%m\"`"
	;;
"date")
	if [ $# -lt 4 ];then
		echo "ERROR: you must specify a date (yyyy-mm-dd)"
		exit 1
	else
		DATESTART="`date --date=\"$4\" \"+%Y-%m-%d 00:00:00 +00:00\"`"
		DATEEND="`date   --date=\"$4\" \"+%Y-%m-%d 23:59:59 +00:00\"`"
		LOGDATE="`date   --date=\"$4\" \"+%Y%m\"`"
	fi
	;;
*)
	echo "ERROR: INVALID INPUT"
	exit 1
	;;
esac
	
LOGFILE="${LOGDIR}/${OSHOST}.${LOGDATE}.${LOGEXT}"
getlogs "$OSHOST" "$OSPASS" "$DATESTART" "$DATEEND" "$LOGFILE"

	
# CLEAN UP ---------------------------------------------------------------------
if [ -f $TMPFILE ];then
        rm -f $TMPFILE
fi
if [ "$KEEPLOG" == "0" ];then
	if [ -f $LOGFILE ];then
		rm -f $LOGFILE
	fi
fi

