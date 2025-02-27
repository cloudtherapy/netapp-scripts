#!/bin/sh
# na_clone-chk.sh : Report on flexclone volumes
#

NACLUSTERS="spinboro aruba"
SSHCMD='ssh -o Batchmode=yes -o LogLevel=ERROR'
TMPFILE=/tmp/na_clone-chk.tmp.$$
CLONES=/tmp/na_clone-chk.clones.$$
REPORTFILE=/tmp/na_baselinei-chk.report.$$
ERRORCOUNT=0

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


echo -n "- Checking for flexclones......................................"


for NACLUSTER in ${NACLUSTERS}
do

    log "   ${NACLUSTER}: Discovering flexclones..."
    ${SSHCMD} ${NACLUSTER} "volume clone show -fields vserver,flexclone,parent-volume,parent-snapshot,junction-path" | tr -d '\r' > ${TMPFILE}

##vserver flexclone   parent-volume parent-snapshot                       junction-path
##------- ----------- ------------- ------------------------------------- ---------------

    cat ${TMPFILE} | egrep -v '^$|Last login|^vserver flexclone|-\-\-\-\-|no entries matching your query|entries were displ' > ${CLONES}
    if [ -s ${CLONES} ]; then
	ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
	awk -v nacluster=${NACLUSTER} '{print "   "nacluster":"$0}' ${CLONES} >> ${REPORTFILE}
    else
	log "   No flexclones found!!! OH YEAH!!!"
    fi

done

if [ ${ERRORCOUNT} -ne 0 ]; then

    echo "WARNING"
    echo "   Flexclones found. Review and deprovision as necessary:"
    echo "   vserver flexclone   parent-volume parent-snapshot                       junction-path"
    echo "   ------- ----------- ------------- ------------------------------------- ---------------"
    cat ${REPORTFILE}
else
    echo "OK. OH YEAH!"
fi


# CLEANUP
rm ${TMPFILE}
rm ${CLONES}
rm ${REPORTFILE}
