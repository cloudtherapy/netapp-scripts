#!/bin/sh
# na_unmount-chk.sh : 
#

. ./environment

TMPFILE=/tmp/na_unmount-chk.tmp.$$
PROBLEMS=/tmp/na_unmount-chk.problems.$$
# VOLEXCUDE : Pattern match to exclude root volumes as well as volumes belonging to cluster SVMs and any SVMs we don't care about
VOLEXCLUDE="_root|_root_m|^svm_I_dont_care_about|^na-cluster"
REPORTFILE=/tmp/na_unmount-chk.report.$$
ERRORCOUNT=0
TODAY=`date -d today '+%m/%d'`

touch ${REPORTFILE}
touch ${PROBLEMS}

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

echo -n "- unmounted volume checks......................................"

for NACLUSTER in ${NACLUSTERS}
do

    log "   ${NACLUSTER}: Checking for unmounted volumes..."
    ${SSHCMD} ${NACLUSTER} 'volume show  -junction-path - -fields junction-path' | tr -d '\r' > ${TMPFILE}
    cat ${TMPFILE} | awk '/\-\-\-\-\-/,EOF' | egrep -v '^$|Last login|entries were displ|There are no entries matching your query' | egrep -v "${VOLEXCLUDE}" > ${PROBLEMS}
    if [ `egrep -v '^vserver|\-\-\-\-' ${PROBLEMS} | wc -l` -ne 0 ]; then
        ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
        echo "   WARNING:The following volumes are NOT mounted:" >> ${REPORTFILE}
        awk '{print "   "$0}' ${PROBLEMS} >> ${REPORTFILE}
    else
        log "   No unmounted volumes found for {$NACLUSTER}!!! OH YEAH!!!"
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
rm ${PROBLEMS}
rm ${REPORTFILE}
