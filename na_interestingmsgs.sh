#!/bin/sh
# na_interestingmsgs.sh
#
. ./environment

# Report on NetApp aggregate utilization
${NTAPHOME}/na_aggr_info.sh > ${OUTPUTFILE}

echo "" >> ${OUTPUTFILE}
echo "" >> ${OUTPUTFILE}

# General NetApp sanity checks follows:

echo "=====================" >> ${OUTPUTFILE}
echo "Netapp sanity checks" >> ${OUTPUTFILE}
echo "=====================" >> ${OUTPUTFILE}
echo "" >> ${OUTPUTFILE}

# Collect ONTAP versions
${NTAPHOME}/na_versions.sh >> ${OUTPUTFILE}

# Check cluster health
${NTAPHOME}/na_clusterhealth.sh >> ${OUTPUTFILE}

# Check SVM and volume language configuration
${NTAPHOME}/na_language-chk.sh >> ${OUTPUTFILE}

# Check volumes have logical space reporting/enforcement enabled
${NTAPHOME}/na_logicalspace-chk.sh >> ${OUTPUTFILE}

# Check volume/qtree capacity > 90%:
${NTAPHOME}/na_capacity-chk.sh >> ${OUTPUTFILE}

# Check snapmirror health
${NTAPHOME}/na_snapmirror-chk.sh >> ${OUTPUTFILE}

# Check for flexclones
${NTAPHOME}/na_clone-chk.sh >> ${OUTPUTFILE}

# Check for unmounted volumes
${NTAPHOME}/na_unmount-chk.sh >> ${OUTPUTFILE}

# Check for orphaned CIFS shares
${NTAPHOME}/na_cifs_orphans.sh >> ${OUTPUTFILE}

echo "" >> ${OUTPUTFILE}

   echo "" >> ${OUTPUTFILE}
   echo "" >> ${OUTPUTFILE}
   echo "--------------------------------------------------------------------" >> ${OUTPUTFILE}
   echo "   Brought to you by: ${HOST}:${NTAPHOME}/na_interestingmsgs.sh" >> ${OUTPUTFILE}
   echo "   No expressed warranties..." >> ${OUTPUTFILE}
   cat ${OUTPUTFILE} | tr -d \\r | /bin/mailx -s "NetApp Interesting Messages" -S from=donotreply@${HOST} ${MAILTO}

# Cleanup
rm -f ${OUTPUTFILE}

