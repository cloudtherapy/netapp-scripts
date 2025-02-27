#!/bin/sh
# na_language-chk.sh : Checks SVM and volumes for proper utf8mb8 language setting
#

. ./environment

TMPFILE=/tmp/na_baseline-chk.tmp.$$
SVMLANG=/tmp/na_baseline-chk.svm-lang.$$
VOLS=/tmp/na_baseline-chk.vol.$$
# VOLEXCUDE : Pattern match to exclude root volumes as well as volumes belonging to cluster SVMs and any SVMs we don't care about
VOLEXCLUDE="_root|_root_m|^svm_I_dont_care_about|^na-cluster"
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


echo -n "- utf8mb4 language checks......................................"

for NACLUSTER in ${NACLUSTERS}
do

    log "   ${NACLUSTER}: Checking SVM language..."
    ${SSHCMD} ${NACLUSTER} "vserver show -type data -fields language" | tr -d '\r' > ${TMPFILE}
    cat ${TMPFILE} | egrep -v '^$|utf8mb4|Last login|vserver.*language|-\-\-\-\-|entries were displ' > ${SVMLANG}
    if [ -s ${SVMLANG} ]; then
	ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
	echo "   WARNING:SVMs not configured with utf8mb4:" >> ${REPORTFILE}
	awk -v nacluster=${NACLUSTER} '{print "   "nacluster":"$0}' ${SVMLANG} >> ${REPORTFILE}
    else
	log "   All SVMs configured with utf8mb4!!! OH YEAH!!!"
    fi

    log "   ${NACLUSTER}: Checking volumes..."
    log "   Excluding: ${VOLEXCLUDE}"
    ${SSHCMD} ${NACLUSTER} "volume show -fields language,volume-style-extended" | tr -d '\r' > ${TMPFILE}
    cat ${TMPFILE} | egrep -v '^$|utf8mb4|Last login|vserver.*language|-\-\-\-\-|entries were displ' |egrep -v ${VOLEXCLUDE} > ${VOLS}
    if [ -s ${VOLS} ]; then
	ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
	echo "   WARNING:Volumes found not configured with utf8mb4:" >> ${REPORTFILE}
	awk -v nacluster=${NACLUSTER} '{print "   "nacluster":"$0}' ${VOLS} >> ${REPORTFILE}
    else
	log "  All Volumes configured with utf8mb4!!! OH YEAH!!!"
    fi
    
done

if [ ${ERRORCOUNT} -ne 0 ]; then

    echo "WARNING"
    cat ${REPORTFILE}
else
    echo "OK. OH YEAH!"
fi


# CLEANUP
rm ${TMPFILE}
rm ${SVMLANG}
rm ${VOLS}
rm ${REPORTFILE}
