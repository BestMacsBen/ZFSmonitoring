#!/bin/bash

#vars
timeStamp=`date +"%Y-%m-%d %H:%M"`
scriptHome="/Users/admin/Scripts"
zpoolName="Artie"
logPath="/Library/Logs/zpoolMonitor"
logFile="$logPath/$zpoolName-Status.log"
poolStatusFull=`zpool status "$zpoolName"`
pushoverToken="a4gVLJ8W9SaH5UgMkt2wLeeN7VcWmb"
pushoverUser="uvdkMbYeh96B2pu5QMaRNtcgNvJUdb"

#Logging setup
if [ ! -d "$logPath" ]; then
	mkdir -p "$logPath"
	chmod 777 "$logPath"
fi

#Setup arguements
case "$1" in
	"debug")
		debugFlag="yes"
		;;
	"mute")
		pushoverToken="null-value-to-screw-function"
		;;
esac

#Function for sending pushover notifications
pushNotification () {
	curl -s -F "token=$pushoverToken" -F "user=$pushoverUser" -F "title=ZFS Pool Issue" -F "message=$1" https://api.pushover.net/1/messages.json >/dev/null
}

#check status of zpool
poolStatus=`echo "$poolStatusFull" | grep "^ state:" | awk -F ': ' '{ print $2 }'`

#Debug code
if [ "$debugFlag" == "yes" ]; then
	poolStatus="$2"
fi

#Parse the status and act on it
case "$poolStatus" in
	"ONLINE")
		scanKeyword=`echo "$poolStatusFull" | grep "^  scan:" | awk -F ': ' '{ print $2 } ' | awk -F ' ' '{ print $1$2 }' | awk 'NF > 0'`
		if [ "$scanKeyword" == "scrubin" ];then
			scanStatus=`echo "$poolStatusFull" | grep -A 2 "^  scan:"`
		else
			scanStatus=`echo "$poolStatusFull" | grep "^  scan:"`
		fi
		printf "$timeStamp - ONLINE $scanStatus \n" >> "$logFile"
		#Clear locks from bad checks since now is good
		if [ -e "$scriptHome/"$zpoolName"DEGRADED" ] || [ -e "$scriptHome/"$zpoolName"FAULTED" ]; then
			rm "$scriptHome/"$zpoolName"DEGRADED" "$scriptHome/"$zpoolName"FAULTED" 2>/dev/null
			echo "$timeStamp - [NOTE] Cleared a notification flag" >> "$logFile"
			pushNotification "Issue on $zpoolName cleared."
		fi
		;;
	"OFFLINE")
		echo "$timeStamp - OFFLINE Volume was manually offline'd." >> "$logFile"
		;;
	"DEGRADED")
		poolConfig=`echo "$poolStatusFull" | awk '/config:/{y=1;next}y' | awk 'NF > 0'`
		printf "$timeStamp - DEGRADED $poolConfig \n" >> "$logFile"
		if [ ! -f "$scriptHome/"$zpoolName"DEGRADED" ]; then
			echo "$timeStamp" > "$scriptHome/"$zpoolName"DEGRADED"
			echo "$timeStamp - [NOTE] Sent Notification and set notification flag." >> "$logFile"
			pushNotification "$zpoolName status Degraded"
		else
			noteSentTime=`cat "$scriptHome/"$zpoolName"DEGRADED"`
			echo "$timeStamp - [NOTE] Existing notification was sent on $noteSentTime" >> "$logFile"
		fi
		;;
	"FAULTED" | "UNAVAIL" | "REMOVED")
		poolConfig=`echo "$poolStatusFull" | awk '/config:/{y=1;next}y' | awk 'NF > 0'`
		printf "$timeStamp - CRITICAL FAILURE $poolConfig \n" >> "$logFile"
		if [ ! -f "$scriptHome/"$zpoolName"FAULTED" ]; then
			echo "$timeStamp" > "$scriptHome/"$zpoolName"FAULTED"
			echo "$timeStamp - [NOTE] Sent Notification and set notification flag." >> "$logFile"
			pushNotification "$zpoolName status FAULTED"
		else
			noteSentTime=`cat "$scriptHome/"$zpoolName"FAULTED"`
			echo "$timeStamp - [NOTE] Existing notification was sent on $noteSentTime" >> "$logFile"
		fi
		;;
	* )
		echo "$timeStamp - UNKNOWN error." >> "$logFile"
		;;
esac

#lets do some log management

#Determine that month of the current log and the month we are currently in
currentLogMonth=`head -n 1 "$logFile" | awk -F ' ' '{print $1}' | awk -F '-' '{print $1"-"$2}'`
currentMonth=`date +"%Y-%m"`
if [ $currentLogMonth != $currentMonth ]; then
	#roll the log
	mv "$logFile" ""$logPath"/"$zpoolName"-Status($currentLogMonth).log"
fi
	
exit 0
