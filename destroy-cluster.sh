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
            check_cluster_azure $cluster
            destroy_cluster_azure $cluster
            ;;
        "aws")
            check_cluster_aws $cluster
            destroy_cluster_aws $cluster
            ;;
        *)
            echo "Unrecognised platform, check config.sh"
            exit 1
            ;;
    esac
    rm -f /opt/flight/clusters/$cluster
}

function check_cluster_azure {
    cluster=$1
    if ! az group show --name $cluster &>/dev/null ; then
        cluster_error
    fi
}

function destroy_cluster_azure {
    cluster=$1
    az group delete -y --name $cluster
}

function check_cluster_aws {
    cluster=$1
    if ! aws cloudformation describe-stacks --stack-name $cluster --region $AWS_LOCATION &>/dev/null ; then
        cluster_error
    fi
}

function destroy_cluster_aws {
    cluster=$1
    aws cloudformation delete-stack --stack-name $cluster --region $AWS_LOCATION
}

function cluster_error {
    echo "Cannot find $CLUSTERNAME in specified config."
    echo "Perhaps the wrong config has been used or the cluster has been deleted outside of the builder?"
    echo 
    echo "Exiting without action"
    exit 1
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
