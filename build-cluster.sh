#!/bin/bash

#
# Run this script on a hub
#

# TODO: Ensure enough disk space on gateway to support running jobs, etc
# TODO: Ensure a genders file exists

#################
# Checking Args #
#################

CLUSTERNAME="$1"
SSH_PUB_KEY="$2"
TYPE="gateway2nodes"
PLATFORM="azure"

if [ -z "${CLUSTERNAME}" ] ; then
    echo "Provide cluster name"
    echo "  build-cluster.sh CLUSTERNAME SSH_PUB_KEY"
    exit 1
elif [ -z "${SSH_PUB_KEY}" ] ; then
    echo "Provide ssh public key"
    echo "  build-cluster.sh CLUSTERNAME SSH_PUB_KEY"
    exit 1
fi

###################
# Import to Cloud #
###################
flight cloud cluster init $CLUSTERNAME $PLATFORM
flight cloud import /var/lib/architect/clusters/$TYPE/var/rendered/manifest.yaml > /dev/null

####################
# Deploy Resources #
####################

# Deploy domain/gateway
flight cloud deploy domain && flight cloud deploy gateway1 -p "securitygroup,network1SubnetID=*domain nametext=$CLUSTERNAME user_ssh_pub_key='$SSH_PUB_KEY'"

# Allow enought time for Direct to be setup on gateway
sleep 300

# Deploy nodes
flight cloud deploy node01 -p "securitygroup,network1SubnetID=*domain nametext=$CLUSTERNAME user_ssh_pub_key='$SSH_PUB_KEY'"
flight cloud deploy node02 -p "securitygroup,network1SubnetID=*domain nametext=$CLUSTERNAME user_ssh_pub_key='$SSH_PUB_KEY'"
