#!/bin/bash

#
# Run this script on a hub
#

# TODO: Create a super-tiny minimal hub that can do this so there isn't potential of clashing when launching multiple clusters at once
## Private image that contains pre-configured AWS access keys?
# TODO: Ensure enough disk space on gateway to support running jobs, etc
# TODO: Ensure a genders file exists

#################
# Checking Args #
#################

CLUSTERNAME="$1"
SSH_PUB_KEY="$2"

if [ -z "${CLUSTERNAME}" ] ; then
    echo "Provide cluster name"
    echo "  do-it.sh CLUSTERNAME SSH_PUB_KEY"
    exit 1
elif [ -z "${SSH_PUB_KEY}" ] ; then
    echo "Provide ssh public key"
    echo "  do-it.sh CLUSTERNAME SSH_PUB_KEY"
    exit 1
fi

###########################
# Keep Plugins Up-To-Date #
###########################

# Put plugins in place
if ! [ -d /tmp/flight-architect ] ; then
    git clone https://github.com/openflighthpc/flight-architect /tmp/flight-architect
fi
cd /tmp/flight-architect
git checkout feature/plugins
git pull
rsync -auv /tmp/flight-architect/data/example/ /opt/flight/opt/architect/data/example/

################
# Set Build IP #
################

IP="$(curl -f http://169.254.169.254/latest/meta-data/public-ipv4 2> /dev/null)"
if [ $? != 0 ] ; then
    ## Azure IP
    IP="$(curl -f -H Metadata:true 'http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2019-06-01&format=text')"
fi
sed -i "s,renderedurl:.*,renderedurl: http://$IP/architect/<%=node.config.cluster%>/var/rendered/<%=node.platform%>/node/<%=node.name%>,g" /opt/flight/opt/architect/data/base/etc/configs/domain.yaml

######################
# Create New Cluster #
######################

# Initialise cluster
set +m # Silence background job creation message
{ flight architect cluster init $CLUSTERNAME > /dev/null & } 2>/dev/null
PID=$!
sleep 5
kill -9 $PID 2> /dev/null
set -m # Enable background job creation message

# Configure domain
flight architect configure domain -a "{ \"cluster_name\": \"$CLUSTERNAME\", \"root_password\": \"$(openssl rand -base64 16)\", \"root_ssh_key\": \"empty-key-no-root-ssh\", \"network2_defined\": false, \"network3_defined\": false }"
echo "user_ssh_pub_key: $SSH_PUB_KEY" >> /var/lib/underware/clusters/$CLUSTERNAME/etc/configs/nodes/gateway1.yaml

# Generate Templates
flight architect template
cp /var/lib/underware/clusters/$CLUSTERNAME/var/rendered/kickstart/domain/platform/manifest.yaml /var/lib/underware/clusters/$CLUSTERNAME/var/rendered/

# Import to cloud
flight cloud cluster init $CLUSTERNAME aws
flight cloud import /var/lib/underware/clusters/$CLUSTERNAME/var/rendered/manifest.yaml > /dev/null

####################
# Deploy Resources #
####################

# Deploy domain/gateway
flight cloud deploy domain && flight cloud deploy gateway1 -p 'securitygroup,network1SubnetID=*domain'

# Allow enought time for Direct to be setup on gateway
sleep 240

# Deploy nodes
flight cloud deploy -g nodes -p 'securitygroup,network1SubnetID=*domain'
