#!/bin/sh
#
# na_cifs_orphans.sh : Find cifs shares which are not currently mounted on the filesystem.
#                      Cifs shares can be orphaned when volumes are deprovisioned incompletely.
#
# NOTE: This script may return false positives for deeply nested shares, however, these are not best practice in themselves anyway!
#
#       PHASE 1 Scan: Compare CIFS share paths with existing volume junction-paths
#       PHASE 2 Scan: The con-compliant shares from PHASE1 and search for path with "file-directory show" (Expensive Operation)
#
# CHANGELOG:
#
NACLUSTERS="spinboro aruba"
# CIFSEXCLUDE : Ignore default ADMIN shares etc + SVMs we don't care about + Chop header
CIFSEXCLUDE='#admin\$#|#/\.admin#|^SVM_I_DONT_CARE_ABOUT|#c\$#|#ipc\$#|vserver#share'
SSHCMD='ssh -n -o Batchmode=yes -o LogLevel=ERROR'
ONTAP_STD_ARGS="set -units B; set -showseparator \"#\"; set -showallfields true"
CIFSLIST=/tmp/na_cifs_orphans.cifs.$$
VOLPATHS=/tmp/na_cifs_orphans.volpaths.$$
TMPFILE=/tmp/na_cifs_orphans.tmp.$$
PHASE1LIST=/tmp/na_cifs_orphans.phase1.$$
ERRFILE=/tmp/na_cifs_orphans.err.$$

echo -n "- Checking for orphaned CIFS shares............................"

cat /dev/null > ${ERRFILE}

for NACLUSTER in ${NACLUSTERS}
do

   cat /dev/null > ${PHASE1LIST}

   # Collect CIFS share paths:
   ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS}; cifs share show -fields vserver,share-name,path" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}
   egrep -vi ${CIFSEXCLUDE} ${TMPFILE} > ${CIFSLIST}

#DEBUG#   cp ${CIFSLIST} ${CIFSLIST}_${NACLUSTER}

   # Collect Volume junction-paths:
   ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS}; volume show -fields vserver,volume,junction-path" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${VOLPATHS}

#DEBUG#   cp ${VOLPATHS} ${VOLPATHS}_${NACLUSTER}

   if [ -s ${CIFSLIST} ] ; then

       while read CIFSSHARE
       do
	   # FIRST PASS: Check for cifs path in mounted volume junction-paths
	   
	   VSERVER=`echo ${CIFSSHARE} | awk -F# '{print $1}'`
	   SHARENAME=`echo ${CIFSSHARE} | awk -F# '{print $2}'`
	   CIFSPATH=`echo ${CIFSSHARE} | awk -F# '{print $3}'`
	   
	   VOLPATHFOUND=`egrep "^${VSERVER}#.*#${CIFSPATH}#$" ${VOLPATHS} > /dev/null; echo $?`
	   
	   if [ "x${VOLPATHFOUND}x" = "x1x" ]; then
	       echo "${VSERVER}#${SHARENAME}#${CIFSPATH}" >> ${PHASE1LIST}
	   fi
	   
       done < ${CIFSLIST}
       
 #DEBUG#      cp ${PHASE1LIST} ${PHASE1LIST}_${NACLUSTER}

       if [ -s ${PHASE1LIST} ] ; then
	   while read CIFSSHARE
	   do
	       # SECOND PASS: Check if folder exists w/ vserver file-directory show command (expensive)
	       
	       VSERVER=`echo ${CIFSSHARE} | awk -F# '{print $1}'`
	       SHARENAME=`echo ${CIFSSHARE} | awk -F# '{print $2}'`
	       CIFSPATH=`echo ${CIFSSHARE} | awk -F# '{print $3}'`
	       
	       ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS}; vserver security file-directory show-effective-permissions -vserver ${VSERVER} -path \"${CIFSPATH}\" -unix-user-name root -fields path" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}
	       
	       PATHNOTFOUND=`egrep "No such file or directory" ${TMPFILE} > /dev/null; echo $?`
	       
	       if [ "x${PATHNOTFOUND}x" = "x0x" ]; then
		   echo "${VSERVER}#${SHARENAME}#${CIFSPATH}" >> ${ERRFILE}
##DEBUG#		   echo "NOT FOUND: ${VSERVER}#${SHARENAME}#${CIFSPATH}"
##DEBUG# 	       else
##DEBUG# 		   echo "OK: ${VSERVER}#${SHARENAME}#${CIFSPATH}"
	       fi
	       
	   done < ${PHASE1LIST}
       fi
   fi

done

# Report results...
if [ -s ${ERRFILE} ]; then
    echo "WARNING"
    echo "   WARNING:The following CIFS share paths do not appear to be associated with a mounted volume:"
    sort ${ERRFILE} | gawk -F#  '{printf("   %-30s  %s\n","//"$1"/"$2,"PATH="$3)}' > ${TMPFILE}
    cat ${TMPFILE}
else
   echo "OK. OH YEAH!"
fi

# CLEANUP
rm ${CIFSLIST}
rm ${VOLPATHS}
rm ${TMPFILE}
rm ${PHASE1LIST}
rm ${ERRFILE}
