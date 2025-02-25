#!/bin/sh
# na_versions.sh : Collect NetApp clusters ONTAP version
#

NACLUSTERS="na-cluster1 na-cluster2 na-cluster3 na-cluster4"
SSHCMD='ssh -o Batchmode=yes -o LogLevel=ERROR'
TMPFILE=/tmp/na_versions.tmp.$$
REPORTFILE=/tmp/na_versions.report.$$
ERRORCOUNT=0

echo "- ONTAP Versions:" > ${REPORTFILE}

for NACLUSTER in ${NACLUSTERS}
do

    ${SSHCMD} ${NACLUSTER} "version" | tr -d '\r' | egrep -i 'NetApp Release' > ${TMPFILE}
    #NetApp Release 9.15.1P3: Wed Sep 25 22:33:44 UTC 2024
    echo -n "  ${NACLUSTER}: " >> ${REPORTFILE}
    grep -i netapp ${TMPFILE} >> ${REPORTFILE}

done

cat ${REPORTFILE}

# CLEANUP
rm -f ${TMPFILE}
rm -f ${REPORTFILE}
