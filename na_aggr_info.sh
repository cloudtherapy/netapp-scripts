#!/bin/sh
#
# na_aggr_info.sh : Returns NetApp aggregrate utilization
#
# CHANGELOG:
#    20200808 : Inception  -Jky
#    20221118 : Add A400/A250  -Jky
#
NACLUSTERS="na-cluster1 na-cluster2 na-cluster3 na-cluster4"
SSHCMD='ssh -o Batchmode=yes -o LogLevel=ERROR'
ONTAP_STD_ARGS="set -units B; set -showseparator \"#\"; set -showallfields true"
VOLLIST=/tmp/na_aggr_info.vols.$$
AGGRINFO=/tmp/na_aggr_info.aggr.$$
AGGRLIST=/tmp/na_aggr_info.aggrlist$$
AGGROBJINFO=/tmp/na_aggr_info.aggrobjinfo.$$
VFOOTPRINT=/tmp/na_volcounts.vfootprt.$$
TMPFILE=/tmp/na_aggr_info.tmp.$$

echo "NetApp aggregate utilization:"

   # Print header:
   echo "" |awk '{printf("%-11s %-25s %-7s %-7s %-7s %-5s %-8s %-9s %-5s %-7s %s\n","CLUSTER","AGGREGATE","SIZE","AVAIL","USED","USED","OBJECT","PROV","VOL","STATE","RAIDSTATUS")}'
   echo "" |awk '{printf("%-11s %-25s %-7s %-7s %-7s %-5s %-8s %-9s %-5s %-7s %s\n","","","(TB)","(TB)","(TB)","(%)","USED(TB)","(TB)","COUNT","","")}'
   echo "----------  ------------------------  ------  ------  ------  ----  -------  --------  ----- ------- --------------"


for NACLUSTER in ${NACLUSTERS}
do

   # Collect Aggregate Info:
   ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS}; aggr show" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}
   grep -vi '^aggregate#' ${TMPFILE} > ${AGGRINFO}

##aggregate#storage-type#aggregate-type#chksumstyle#diskcount#mirror#disklist#mirror-disklist#partitionlist#mirror-partitionlist#node#nodes#free-space-realloc#ha-policy#ignore-inconsistent#percent-snapshot-space#space-nearly-full-threshold-percent#space-full-threshold-percent#raid-checksum-verify#raid-lost-write#thorough-scrub#hybrid-enabled#availsize#chksumenabled#chksumstatus#cluster#cluster-id#dr-home-id#dr-home-name#inofile-version#has-mroot#has-partner-mroot#home-id#home-name#hybrid-cache-size-total#hybrid#inconsistent#is-home#maxraidsize#cache-raid-group-size#owner-id#owner-name#percent-used#plexes#raidgroups#raid-lost-write-state#raidstatus#raidtype#resyncsnaptime#resync-snap-time#root#sis-metadata-space-used#size#state#max-write-alloc-blocks#usedsize#uses-shared-disks#uuid#volcount#is-flash-pool-caching-enabled#is-autobalance-eligible#autobalance-state#physical-used#physical-used-percent#autobalance-state-change-counter#snaplock-type#is-nve-capable#is-cft-precommit#is-transition-out-of-space#autobalance-unbalanced-threshold-percent#autobalance-available-threshold-percent#resync-priority#data-compaction-space-saved#data-compaction-space-saved-percent#data-compacted-count#creation-timestamp#single-instance-data-logging#composite#is-fabricpool-mirrored#is-cloud-mirrored#composite-capacity-tier-used#sis-space-saved#sis-space-saved-percent#sis-shared-count#is-inactive-data-reporting-enabled#azcs-read-optimization-enabled#encrypt-with-aggr-key#drive-protection-enabled#

   # List of aggregates:
   awk -F# '{print $1}' ${AGGRINFO} > ${AGGRLIST}

   # Determine field numbers for interesting information in AGGRINFO header:
   AGGRSIZE=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "size") print i }' ${TMPFILE}`
   AGGRAVAIL=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "availsize") print i }' ${TMPFILE}`
   AGGRUSED=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "usedsize") print i }' ${TMPFILE}`
   AGGRUSEDPCT=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "percent-used") print i }' ${TMPFILE}`
   AGGRVOLCNT=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "volcount") print i }' ${TMPFILE}`
   AGGRSTATE=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "state") print i }' ${TMPFILE}`
   AGGRRAIDS=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "raidstatus") print i }' ${TMPFILE}`


   # Collect Aggregate Object Store Utilization:
   ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS}; aggr show-space" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}
   grep -vi '^aggregate' ${TMPFILE} > ${AGGROBJINFO}

   # Determine field numbers for interesting information in AGGRBJINFO header:
   TIERNAME=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "tier-name") print i }' ${TMPFILE}`
   OBJPHYUSED=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "object-store-physical-used") print i }' ${TMPFILE}`

   # Collect Volume Information to determine total provisioned storage:
   ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS}; volume show" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}
   grep -vi '^vserver' ${TMPFILE} > ${VOLLIST}

   # Determine field numbers for interesting information in VOLINFO header:
   VOLAGGR=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "aggregate") print i }' ${TMPFILE}`
   VOLSIZE=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "size") print i }' ${TMPFILE}`

   # Print Aggregate Info:
   for AGGR in `cat ${AGGRLIST}`
   do

       # Get Object-Store physical usage stats collected separately:
       OBJPHYUSED_BYTES=`awk -F# -v aggr=${AGGR} -v tiername=${TIERNAME} -v objphyused=${OBJPHYUSED} '($1==aggr)&&($tiername~/Object Store/) {print $objphyused}' ${AGGROBJINFO}`

       # Get Provisioned usage stats collected separately:
       PROVISIONED_BYTES=`awk -F# -v aggr=${AGGR} -v volaggr=${VOLAGGR} -v volsize=${VOLSIZE} '($volaggr==aggr) {i+=substr($volsize,1,length($volsize)-1)} END {printf("%d\n",i)}' ${VOLLIST}`


       # Good luck to you if you can understand fieldnumber variable substitution!
       # e.g.
       # aggrsize : This is the field number for the aggregate size information in AGGRINFO.  In the awk statement, $aggrsize 
       #            translates to print out the contents located in fieldnumber, $aggrsize
       # objphyused_bytes:  Conversely, this is a straight shell variable containing the object-store physical usage size 
       #            passed to awk.  You will notice that objphyused_bytes is NOT dereference with a preceding "$".

       # gsub() used to replace unwanted quotes are spaces as appropriate
       # substr() used to chop the leaded "B" for bytes in the size inputs

       #NACLUSTER,aggregate,size,available,used,aggrusedpct,objphyused,provisionedsize,volumecount,state,raidstatus


       awk -F# -v nacluster=${NACLUSTER} -v aggr=${AGGR} -v aggrsize=${AGGRSIZE} -v aggravail=${AGGRAVAIL} -v aggrused=${AGGRUSED} -v aggrusedpct=${AGGRUSEDPCT} -v objphyused_bytes=${OBJPHYUSED_BYTES} -v provisioned_bytes=${PROVISIONED_BYTES} -v aggrvolcnt=${AGGRVOLCNT} -v aggrstate=${AGGRSTATE} -v aggrraids=${AGGRRAIDS} '($1==aggr) {gsub(/"/,"",$aggrraids);gsub(/, /,":",$aggrraids);printf("%-11s %-24s %7.2f %7.2f %7.2f %4d%%  %7.2f %9.2f %6s %-7s %s\n",nacluster,aggr,substr($aggrsize,1,length($aggrsize)-1)/1024/1024/1024/1024,substr($aggravail,1,length($aggravail)-1)/1024/1024/1024/1024,substr($aggrused,1,length($aggrused)-1)/1024/1024/1024/1024,$aggrusedpct,substr(objphyused_bytes,1,length(objphyused_bytes)-1)/1024/1024/1024/1024,provisioned_bytes/1024/1024/1024/1024,$aggrvolcnt,$aggrstate,$aggrraids)}' ${AGGRINFO}

   done

done 





# CLEANUP
rm ${VOLLIST}
rm ${AGGRLIST}
rm ${AGGRINFO}
rm ${AGGROBJINFO}
rm ${TMPFILE}

