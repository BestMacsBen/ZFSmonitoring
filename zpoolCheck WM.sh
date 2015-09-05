#!/bin/bash

# 0 - We're All Good = Information will be displayed at the server, but not emailed.
# 2 - Big Problem! = This information will be displayed on the server, and trigger an email.
# 20 - Information worth reporting was found, but no email should be sent.
# 25 - Nothing to see here = Information will not be sent to the server (and not emailed)

zpoolInstalled=`whereis zpool`
if [ -n "$zpoolInstalled" ];then
	#vars
	timeStamp=`date +"%Y-%m-%d %H:%M"`
	zpoolsList=`zpool list -H | awk -F '\t'  '{print $1}'`
	exitCode=0

	# Loops through the list of pools and process status
	saveIFS="$IFS"
	IFS=$(echo -en "\n\b")
	for thisPool in `printf "$zpoolsList"`; do
		IFS="$saveIFS"
		#check status of zpool
		poolStatusFull=`zpool status "$thisPool"`
		poolStatus=`echo "$poolStatusFull" | grep "^ state:" | awk -F ': ' '{ print $2 }'`

		#Parse the status and act on it
		case "$poolStatus" in
			"ONLINE")
				scanKeyword=`echo "$poolStatusFull" | grep "^  scan:" | awk -F ': ' '{ print $2 } ' | awk -F ' ' '{ print $1$2 }' | awk 'NF > 0'`
				if [ "$scanKeyword" == "scrubin" ];then
					scanStatus=`echo "$poolStatusFull" | grep -A 2 "^  scan:"`
				else
					scanStatus=`echo "$poolStatusFull" | grep "^  scan:"`
				fi
				echo "$thisPool status: $poolStatus"
				echo "$scanStatus"
				exitCode=0
				;;
			"OFFLINE")
				echo "$thisPool status: $poolStatus"
				echo "$thisPool was manually offline'd"
				exitCode=0
				;;
			"DEGRADED")
				poolConfig=`echo "$poolStatusFull" | awk '/config:/{y=1;next}y' | awk 'NF > 0'`
				echo "$thisPool status: $poolStatus"
				echo "$poolConfig"
				exitCode=2
				;;
			"FAULTED" | "UNAVAIL" | "REMOVED")
				poolConfig=`echo "$poolStatusFull" | awk '/config:/{y=1;next}y' | awk 'NF > 0'`
				echo "$thisPool status: $poolStatus"
				echo "$poolConfig"
				exitCode=2
				;;
			* )
				echo "$thisPool has an unknown error: $poolStatus"
				exitCode=20
				;;
		esac
	done
	IFS="$saveIFS"
else
	#zpool not installed
	exitCode=25
fi