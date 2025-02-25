#!/bin/sh
# na_snapmirror-chk.sh : 
#

NACLUSTERS="na-cluster1 na-cluster2 na-cluster3 na-cluster4"
SSHCMD='ssh -o Batchmode=yes -o LogLevel=ERROR'
TMPFILE=/tmp/na_snapmirror-chk.tmp.$$
PROBLEMS=/tmp/na_snapmirror-chk.problems.$$
# VOLEXCUDE : Pattern match to exclude root volumes as well as volumes belonging to cluster SVMs and any SVMs we don't care about
VOLEXCLUDE="_root|_root_m|^svm_I_dont_care_about|^na-cluster"
REPORTFILE=/tmp/na_snapmirror-chk.report.$$
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

echo -n "- snapmirror checks............................................"

for NACLUSTER in ${NACLUSTERS}
do

##nacluster::> volume show -logical-used-percent >90 -fields size,total,used,logical-used,logical-used-percent
##vserver   volume                 size total  used   logical-used logical-used-percent
##--------- ---------------------- ---- ------ ------ ------------ --------------------

    log "   ${NACLUSTER}: Checking for unhealthy snapmirrors..."
    ${SSHCMD} ${NACLUSTER} 'snapmirror show -healthy false' | tr -d '\r' > ${TMPFILE}
    cat ${TMPFILE} | awk '/\-\-\-\-\-/,EOF' | egrep -v '^$|Last login|entries were displ|There are no entries matching your query' | egrep -v ${VOLEXCLUDE} > ${PROBLEMS}
    if [ `egrep -v '^vserver|\-\-\-\-' ${PROBLEMS} | wc -l` -ne 0 ]; then
        ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
        echo "   WARNING:The following snapmirrors are unhealthy:" >> ${REPORTFILE}
        awk '{print "   "$0}' ${PROBLEMS} >> ${REPORTFILE}
    else
        log "   No unhealthy snapmirrors found for {$NACLUSTER}!!! OH YEAH!!!"
    fi

    log "   ${NACLUSTER}: Checking for delayed snapmirrors..."
    ${SSHCMD} ${NACLUSTER} "snapmirror show -last-transfer-end-timestamp < ${TODAY} 00:00:00 -fields last-transfer-end-timestamp" | tr -d '\r' > ${TMPFILE}
    cat ${TMPFILE} | egrep -v '^$|Last login|entries were displ|There are no entries matching your query' | egrep -v ${VOLEXCLUDE} > ${PROBLEMS}
    if [ `egrep -v '^source|\-\-\-\-' ${PROBLEMS} | wc -l` -eq 0 ]; then
	# No errors encounted. Clear out temp file.
	cat /dev/null > ${TMPFILE}
    fi
    case ${NACLUSTER} in
	na-cluster2|na-cluster4) # Allow for 24 hour delay for larger snapmirror target clusters
	    MAXLAGDELAY="24:00:00"
	;;
	*) # Default delay allowance:
	    MAXLAGDELAY="3:00:00"
	;;
    esac
    ${SSHCMD} ${NACLUSTER} "snapmirror show -lag-time > ${MAXLAGDELAY} -fields lag-time" | tr -d '\r' >> ${TMPFILE}
    cat ${TMPFILE} | egrep -v '^$|Last login|entries were displ|There are no entries matching your query' | egrep -v ${VOLEXCLUDE} > ${PROBLEMS}
    if [ `egrep -v '^source|\-\-\-\-' ${PROBLEMS} | wc -l` -ne 0 ]; then
        ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
        echo "   WARNING:The following snapmirrors are delayed:" >> ${REPORTFILE}
        awk '{print "   "$0}' ${PROBLEMS} >> ${REPORTFILE}
    else
        log "   No delayed snapmirrors found for {$NACLUSTER}!!! OH YEAH!!!"
    fi

    #echo "" >> ${REPORTFILE}


##na-cluster::> quota report -volume ist -fields disk-limit,disk-used-pct-disk-limit,disk-used,volume,tree,volume -disk-used-pct-disk-limit >80
##vserver volume index               tree disk-used disk-limit disk-used-pct-disk-limit
##------- ------ ------------------- ---- --------- ---------- ------------------------

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
