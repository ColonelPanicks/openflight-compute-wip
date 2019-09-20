#!/bin/bash

#
# Run this script on a hub
#

# TODO: Ensure enough disk space on gateway to support running jobs, etc

#################
# Checking Args #
#################

CLUSTERNAME="$1"
SSH_PUB_KEY="$2"
TYPE="basic"
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
flight cloud domain create /var/lib/architect/clusters/$TYPE/var/rendered/$PLATFORM/domain/platform/domain.* > /dev/null
flight cloud node create gateway1 /var/lib/architect/clusters/$TYPE/var/rendered/$PLATFORM/node/gateway1/platform/gateway1.*
flight cloud node create node01 /var/lib/architect/clusters/$TYPE/var/rendered/$PLATFORM/node/node01/platform/node01.*
flight cloud node create node02 /var/lib/architect/clusters/$TYPE/var/rendered/$PLATFORM/node/node02/platform/node02.*

flight cloud group create nodes
flight cloud group add -p nodes node01 node02

####################
# Deploy Resources #
####################

# Deploy domain/gateway
flight cloud domain deploy
flight cloud node deploy gateway1 "securitygroup,network1SubnetID=*domain nametext=$CLUSTERNAME user_ssh_pub_key='$SSH_PUB_KEY'"

# Deploy nodes
flight cloud node deploy node01 "securitygroup,network1SubnetID=*domain nametext=$CLUSTERNAME user_ssh_pub_key='$SSH_PUB_KEY'"
flight cloud node deploy node02 "securitygroup,network1SubnetID=*domain nametext=$CLUSTERNAME user_ssh_pub_key='$SSH_PUB_KEY'"
