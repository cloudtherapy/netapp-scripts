#!/bin/sh
# na_logicalspace-chk.sh : Identifies volumes that do not have logical space reporting/enforcement enabled
#

. ./environment

TMPFILE=/tmp/na_logicalspace-chk.tmp.$$
LOGSPACE_DISABLED=/tmp/na_logicalspace-chk.disabled.$$
# VOLEXCUDE : Pattern match to exclude root volumes as well as volumes belonging to cluster SVMs and any SVMs we don't care about
VOLEXCLUDE="_root|_root_m|^svm_I_dont_care_about|^na-cluster"
REPORTFILE=/tmp/na_logicalspace-chk.report.$$
ERRORCOUNT=0

touch ${REPORTFILE}

if [ "x$1x" = "x-vx" ]; then
   VERBOSE=1
else
   VERBOSE=0
fi

function log () {
    if [ ${VERBOSE} -eq 1 ]; then
        echo "$@" >> ${REPORTFILE}
    fi
}

echo -n "- logical space reporting/enforcement checks(A300 ONLY)........"

for NACLUSTER in ${NACLUSTERS}
do

    log "   ${NACLUSTER}: Checking logical space settings..."
### LOGICAL SPACE REPORTING IS NOT SUPPORTED ON DP VOLUMES ###
    ${SSHCMD} ${NACLUSTER} 'volume show -is-space-reporting-logical false -type !DP -fields volume' | tr -d '\r' > ${TMPFILE}

    cat ${TMPFILE} | egrep -v '^$|^vserver|Last login|vserver.*is-space-reporting|-\-\-\-\-|entries were displ' | egrep -v ${VOLEXCLUDE} > ${LOGSPACE_DISABLED}
    if [ -s ${LOGSPACE_DISABLED} ]; then
	ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
	echo "   WARNING:logical space reporting not enabled:" >> ${REPORTFILE}
	awk -v nacluster=${NACLUSTER} '{print "   "nacluster":"$0}' ${LOGSPACE_DISABLED} >> ${REPORTFILE}
    else
	log "   All {$NACLUSTER} volumes have logical space reporting enabled!!! OH YEAH!!!"
    fi

    #echo "" >> ${REPORTFILE} 
### LOGICAL SPACE REPORTING IS NOT SUPPORTED ON DP VOLUMES ###
    ${SSHCMD} ${NACLUSTER} 'volume show -is-space-enforcement-logical false -type !DP -fields volume' | tr -d '\r' > ${TMPFILE}

    cat ${TMPFILE} | egrep -v '^$|^vserver|Last login|vserver.*is-space-reporting|-\-\-\-\-|entries were displ' | egrep -v ${VOLEXCLUDE} > ${LOGSPACE_DISABLED}
    if [ -s ${LOGSPACE_DISABLED} ]; then
        ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
        echo "   WARNING:logical space enforcement not enabled:" >> ${REPORTFILE}
        awk -v nacluster=${NACLUSTER} '{print "   "nacluster":"$0}' ${LOGSPACE_DISABLED} >> ${REPORTFILE}
    else
        log "   All {$NACLUSTER} volumes have logical space enforement enabled!!! OH YEAH!!!"
    fi

    #echo "" >> ${REPORTFILE}

done

if [ ${ERRORCOUNT} -ne 0 ]; then

    echo "WARNING"
    cat ${REPORTFILE}
else
    echo "OK. OH YEAH!"
fi


# CLEANUP
rm ${TMPFILE}
rm ${LOGSPACE_DISABLED}
rm ${REPORTFILE}
