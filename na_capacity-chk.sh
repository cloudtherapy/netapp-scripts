#!/bin/sh
# na_capacity-chk.sh : Report volumes/qtrees over 90%
#
# CHANGELOG:   20230530 - For A400/A250 use size instead of logical-size for utilization  -Jky
#
NACLUSTERS="na-cluster1 na-cluster2 na-cluster3 na-cluster4"
SSHCMD='ssh -o Batchmode=yes -o LogLevel=ERROR'
TMPFILE=/tmp/na_capacity-chk.tmp.$$
OVERFLOWED=/tmp/na_capacity-chk.overflow.$$
# VOLEXCUDE : Pattern match to exclude root volumes as well as volumes belonging to cluster SVMs and any SVMs we don't care about
VOLEXCLUDE="_root|_root_m|^svm_I_dont_care_about|^na-cluster"
REPORTFILE=/tmp/na_capacity-chk.report.$$
ERRORCOUNT=0

touch ${REPORTFILE}
touch ${OVERFLOWED}

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

echo -n "- volume/qtree capacity checks................................."



for NACLUSTER in ${NACLUSTERS}
do

##::> volume show -logical-used-percent >90 -fields size,total,used,logical-used,logical-used-percent
##vserver   volume                 size total  used   logical-used logical-used-percent
##--------- ---------------------- ---- ------ ------ ------------ --------------------

    log "   ${NACLUSTER}: Checking flexvol and flexgroup capacities..."
    if [[ ${NACLUSTER} =~ -na2 ]]; then
	${SSHCMD} ${NACLUSTER} 'volume show -volume !*_dest -percent-used >90 -fields volume-style-extended,size,total,used,logical-used,percent-used,snapshot-reserve-available' | tr -d '\r' > ${TMPFILE}
    else
	${SSHCMD} ${NACLUSTER} 'volume show -volume !*_dest -logical-used-percent >90 -fields volume-style-extended,size,total,used,logical-used,logical-used-percent' | tr -d '\r' > ${TMPFILE}
    fi

    ${SSHCMD} ${NACLUSTER} 'volume show -volume !*_dest -volume-style-extended flexgroup* -percent-used >90 -fields volume-style-extended,size,used,percent-used' | tr -d '\r' >> ${TMPFILE}
    ${SSHCMD} ${NACLUSTER} 'quota report -fields quota-type,disk-limit,disk-used-pct-disk-limit,disk-used,volume,tree,volume -disk-used-pct-disk-limit >90' | tr -d '\r' >> ${TMPFILE}

    cat ${TMPFILE} | egrep -v '^$|Last login|entries were displ|There are no entries matching your query' | egrep -v ${VOLEXCLUDE} > ${OVERFLOWED}
    if [ `egrep -v '^vserver|\-\-\-\-' ${OVERFLOWED} | wc -l` -ne 0 ]; then
        ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
        echo "   WARNING:The following volumes/qtrees are over 90% capacity:" >> ${REPORTFILE}
        awk '{print "   "$0}' ${OVERFLOWED} >> ${REPORTFILE}
    else
        log "   No volume capacity warnings for {$NACLUSTER}!!! OH YEAH!!!"
    fi

    #echo "" >> ${REPORTFILE}


##::> quota report -volume ist -fields disk-limit,disk-used-pct-disk-limit,disk-used,volume,tree,volume -disk-used-pct-disk-limit >80
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
rm ${OVERFLOWED}
rm ${REPORTFILE}
