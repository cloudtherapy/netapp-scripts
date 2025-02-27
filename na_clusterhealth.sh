#!/bin/sh
# na_clusterhealth.sh : Checks NetApp cluster health
#

NACLUSTERS="spinboro aruba"
SSHCMD='ssh -o Batchmode=yes -o LogLevel=ERROR'
ONTAP_STD_ARGS="set -showseparator \"#\"; set -showallfields true"
TMPFILE=/tmp/na_clusterhealth.tmp.$$
CLUSTERSHOW=/tmp/na_clusterhealth.clustershow.$$
REPORTFILE=/tmp/na_clusterhealth.report.$$
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


echo -n "- Cluster Health..............................................."

for NACLUSTER in ${NACLUSTERS}
do

    # 1. "cluster show" checks

#Reference:
#Node                 Health  Eligibility   Epsilon
#-------------------- ------- ------------  ------------
#node-01         true    true          false
#node-02         true    true          false
#2 entries were displayed.

    log "   ${NACLUSTER}: cluster show..."
    ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS};set -privilege advanced;cluster show" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}

##node#node-uuid#uuid#epsilon#eligibility#health#
##Node#UUID#UUID#Epsilon#Eligibility#Health#



    EPSILON=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "epsilon") print i }' ${TMPFILE}`
    ELIGIBILITY=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "eligibility") print i }' ${TMPFILE}`
    HEALTH=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "health") print i }' ${TMPFILE}`

    grep -vi '^node#' ${TMPFILE} > ${CLUSTERSHOW}

    NODESFOUND=`grep '.*#.*#.*#' ${CLUSTERSHOW} | wc -l` 
    HEALTHYNODES=`awk -F# -v eligibility=${ELIGIBILITY} -v health=${HEALTH} '($eligibility=="true")&&($health=="true") {print}' ${CLUSTERSHOW} |wc -l`
    EPSILONCOUNT=`awk -F# -v epsilon=${EPSILON} '$epsilon=="true" {print}' ${CLUSTERSHOW} |wc -l`

    case ${NACLUSTER} in
	na-cluster1|na-cluster3|na-cluster4) # Clusters with 2 nodes
		if [ "x$[NODESFOUND]x" = "x2x" ]; then
		    log "   ${NACLUSTER}: Expected number of nodes found."

		    if [ "x$[NODESFOUND]x" = "x${HEALTHYNODES}x" ]; then
			log "   ${NACLUSTER}: All cluster nodes healthy"

			if [ "x${EPSILONCOUNT}x" = "x0x" ]; then
			     log "   ${NACLUSTER}: Expected epsilon count"
			else
			     ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
			     echo "   WARNING:${NACLUSTER} has unexpected epsilon count: ${EPSILONCOUNT}" >> ${REPORTFILE}
			fi

		    else
			ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
			echo "   WARNING:Unhealthy cluster nodes found:" >> ${REPORTFILE}
                    fi

		else
		    ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
                    echo "   WARNING:${NACLUSTER}: Unexpected number of nodes found: ${NODESFOUND}" >> ${REPORTFILE}
		fi
		;;
	na-cluster2) # Clusters with 4 nodes
                if [ "x$[NODESFOUND]x" = "x4x" ]; then
                    log "   ${NACLUSTER}: Expected number of nodes found."

                    if [ "x$[NODESFOUND]x" = "x${HEALTHYNODES}x" ]; then
                        log "   ${NACLUSTER}: All cluster nodes healthy"

                        if [ "x${EPSILONCOUNT}x" = "x1x" ]; then
                             log "   ${NACLUSTER}: Expected epsilon count"
                        else
                             ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
                             echo "   WARNING:${NACLUSTER} has unexpected epsilon count: ${EPSILONCOUNT}" >> ${REPORTFILE}
                        fi

                    else
                        ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
                        echo "   WARNING:Unhealthy cluster nodes found:" >> ${REPORTFILE}
                    fi

                else
                    ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
                    echo "   WARNING:${NACLUSTER}: Unexpected number of nodes found: ${NODESFOUND}" >> ${REPORTFILE}
                fi
		;;
 	*)
		ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
		echo "   WARNING: UNKNOWN CLUSTER: ${NACLUSTER}. Cannot evaluate." >> ${REPORTFILE}
		;;
    esac 

done


for NACLUSTER in ${NACLUSTERS}
do

    # 2. "node show" checks

#Reference:
#Node      Health Eligibility Uptime        Model       Owner    Location
#--------- ------ ----------- ------------- ----------- -------- ---------------
#node-01 true true       89 days 03:33 AFF-A300             Rack G
#node-02 true true       89 days 03:52 AFF-A300


    log "   ${NACLUSTER}: node show..."
    ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS};node show" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}

##node#owner#location#model#serialnumber#assettag#uptime#nvramid#systemid#vendor#health#eligibility#epsilon#uuid#uuid#is-diff-svcs#is-all-flash-optimized#is-capacity-optimized#is-all-flash-select-optimized#
##Node#Owner#Location#Model#Serial Number#Asset Tag#Uptime#NVRAM System ID#System ID#Vendor#Health#Eligibility#Epsilon#UUID#UUID#Differentiated Services#All-Flash Optimized#Capacity Optimized#All-Flash Select Optimized#

    UPTIME=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "uptime") print i }' ${TMPFILE}`
    MODEL=`awk -F# 'NR==1{ for (i=1;i<=NF;i++) if ($i == "model") print i }' ${TMPFILE}`

    grep -vi '^node#' ${TMPFILE} > ${CLUSTERSHOW}

    awk -F# -v uptime=${UPTIME} -v model=${MODEL} '!($uptime)||!($model) {print}' ${CLUSTERSHOW} > ${TMPFILE}
    UNHEALTHYNODES=`cat ${TMPFILE} | wc -l`

    # Friendly output:
    ${SSHCMD} ${NACLUSTER} "node show" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}

    if [ $UNHEALTHYNODES -eq 0 ]; then
	log "   ${NACLUSTER}: No unhealthy nodes found."
    else
	ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
	echo "   WARNING:${NACLUSTER} unhealthy nodes found" >> ${REPORTFILE}
	cat ${TMPFILE} >> ${REPORTFILE}
    fi

done


for NACLUSTER in ${NACLUSTERS}
do

    # 3. "cluster ring show" checks

# Reference:  All nodes should be represented here
#Node      UnitName Epoch    DB Epoch DB Trnxs Master    Online
#-------- -------- -------- -------- -------- --------- ---------
#node-01 mgmt  10       10       459961   node-02 secondary
#node-01 vldb  10       10       1008336  node-02 secondary
#node-01 vifmgr 10      10       1763712  node-02 secondary
#node-01 bcomd 10       10       63       node-02 secondary
#node-01 crs   10       10       1        node-02 secondary
#node-02 mgmt  10       10       459961   node-02 master
#node-02 vldb  10       10       1008336  node-02 master
#node-02 vifmgr 10      10       1763712  node-02 master
#node-02 bcomd 10       10       63       node-02 master
#node-02 crs   10       10       1        node-02 master

    log "   ${NACLUSTER}: cluster ring  show..."
    ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS};set -privilege advanced; cluster ring show" | tr -d '\r' | egrep -vi '^$|^Last login time|^node#' > ${TMPFILE}

##node#unitname#online#epoch#master#local#db-epoch#db-trnxs#num-online#rdb-uuid#
##Node#Unit Name#Status#Epoch#Master Node#Local Node#DB Epoch#DB Transaction#Number Online#RDB UUID#

    RINGNODECOUNT=`awk -F# '{print $1}' ${TMPFILE} | sort -u | wc -l`

    # Friendly output:
    ${SSHCMD} ${NACLUSTER} "set -privilege advanced; cluster ring show" | tr -d '\r' | egrep -vi '^$|^Last login time' > ${TMPFILE}

    case ${NACLUSTER} in
	na-cluster1|na-cluster3|na-cluster4) # Clusters with 2 nodes
	    if [ "x${RINGNODECOUNT}x" = "x2x" ]; then
		log "   ${NACLUSTER}: Cluster ring node count normal."
	    else
		ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
		echo "   WARNING:${NACLUSTER}: Cluster ring node count abnormal, ${RINGNODECOUNT}" >> ${REPORTFILE}
		cat ${TMPFILE} >> ${REPORTFILE}
	    fi
	    ;;
	na-cluster2) # Clusters with 4 nodes
	    if [ "x${RINGNODECOUNT}x" = "x4x" ]; then
		log "   ${NACLUSTER}: Cluster ring node count normal."
	    else
		ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
		echo "   WARNING:${NACLUSTER}: Cluster ring node count abnormal, ${RINGNODECOUNT}" >> ${REPORTFILE}
		cat ${TMPFILE} >> ${REPORTFILE}
	    fi
	    ;;
	*)
	    ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
            echo "   WARNING: UNKNOWN CLUSTER: ${NACLUSTER}. Cannot evaluate." >> ${REPORTFILE}
	    ll
    esac

done


for NACLUSTER in ${NACLUSTERS}
do

    # 4. "system health subsystem show" checks

# Reference:  All subsystems should be in a "ok" state
#Subsystem         Health
#----------------- ------------------
#SAS-connect       ok
#Environment       ok
#Memory            ok
#Service-Processor ok
#Switch-Health     degraded
#CIFS-NDO          ok
#Motherboard       ok
#IO                ok
#MetroCluster      ok
#MetroCluster_Node ok
#FHM-Switch        ok
#FHM-Bridge        ok
#SAS-connect_Cluster ok

    log "   ${NACLUSTER}: system health subsystem show..."
    ${SSHCMD} ${NACLUSTER} "${ONTAP_STD_ARGS};set -privilege advanced; system health subsystem show" | tr -d '\r' | egrep -vi '^$|^Last login time|^node#' > ${TMPFILE}

    SUBSYS_ERRCOUNT=`awk -F# '(tolower($1)!~/subsystem/)&&($2!="ok"){print $1}' ${TMPFILE} | wc -l`

    if [ "x${SUBSYS_ERRCOUNT}x" = "x0x" ] ; then
       log "   ${NACLUSTER}: system health subsystem normal."
    else
       ERRORCOUNT=`expr ${ERRORCOUNT} + 1`
       echo -n "   WARNING: ${NACLUSTER} system health subsystem abnormal: " >> ${REPORTFILE}
                awk -F# '(tolower($1)!~/subsystem/)&&($2!="ok"){print $1" "$2}'  ${TMPFILE} >> ${REPORTFILE}
    fi

done

if [ ${ERRORCOUNT} -ne 0 ]; then

    echo "WARNING"
    cat ${REPORTFILE}
else
    echo "OK. OH YEAH!"
fi


# CLEANUP
rm -f ${TMPFILE}
rm -f ${CLUSTERSHOW}
rm -f ${REPORTFILE}
