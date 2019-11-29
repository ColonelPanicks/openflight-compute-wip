#!/bin/bash

#############
# Variables #
#############

# Get directory of script for locating templates and config
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source variables
if [ -z "${CONFIG}" ] ; then
    source $DIR/configs/default.sh
else
    config_path=$DIR/configs/$CONFIG.sh
    if [ -f $config_path ] ; then
        source $config_path
    else
        echo "Error loading $CONFIG"
        echo "Could not load $config_path"
        exit 1
    fi
fi

CLUSTERS="$(ls /opt/flight/clusters/)"
CLUSTERNAME="$1"

CLUSTERNAMEMATCHES="$(echo "$CLUSTERS" |grep $CLUSTERNAME)"
CLUSTERNAMECOUNT="$(echo "$CLUSTERS" |grep $CLUSTERNAME -c)"

#############
# Functions #
#############

function destroy_cluster {
    cluster=$1
    case $PLATFORM in
        "azure")
            destroy_cluster_azure $cluster
            ;;
        "aws")
            destroy_cluster_aws $cluster
            ;;
        *)
            echo "Unrecognised platform, check config.sh"
            exit 1
            ;;
    esac
    rm -f /opt/flight/clusters/$cluster
}

function destroy_cluster_azure {
    cluster=$1
    az group delete --name $cluster
}

function destroy_cluster_aws {
    cluster=$1
    aws cloudformation delete-stack --stack-name $cluster --region $AWS_REGION
}

#################
# Run Functions #
#################

case $CLUSTERNAMECOUNT in
    0)
        echo "Cluster $CLUSTERNAME doesn't exist"
        ;;
    1)
        destroy_cluster $CLUSTERNAMEMATCHES
        ;;
    *)
        echo "More than one match for clustername:"
        echo "$CLUSTERNAMEMATCHES"
        echo
        echo "Identify the seed for the cluster (check the logs) to narrow down which cluster to delete"
        ;;
esac
