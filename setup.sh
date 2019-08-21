#!/bin/bash
#
# This script will only need to be run once on a hub to prepare 
# cluster configurations for cloud
#

################
# Set Build IP #
################

IP="$(curl -f http://169.254.169.254/latest/meta-data/public-ipv4 2> /dev/null)"
if [ $? != 0 ] ; then
    ## Azure IP
    IP="$(curl -f -H Metadata:true 'http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2019-06-01&format=text' 2>/dev/null)"
fi
sed -i "s,renderedurl:.*,renderedurl: http://$IP/architect/<%=node.config.cluster%>/var/rendered/<%=node.platform%>/node/<%=node.name%>,g" /opt/flight/opt/architect/data/base/etc/configs/domain.yaml

######################################
# Setup OpenFlight Compute Templates #
######################################

# Put into place
if ! [ -d /tmp/flight-architect ] ; then
    git clone https://github.com/openflighthpc/flight-architect /tmp/flight-architect
fi
cd /tmp/flight-architect
git checkout dev/openflight-compute
git pull
rsync -auv /tmp/flight-architect/data/example/ /opt/flight/opt/architect/data/example/

########################
# Create basic cluster #
########################

# Initialise cluster
set +m # Silence background job creation message
{ flight architect cluster init gateway2nodes > /dev/null & } 2>/dev/null
PID=$!
sleep 5
kill -9 $PID 2> /dev/null
set -m # Enable background job creation message

# Configure domain
flight architect configure domain -a "{ \"cluster_name\": \"gateway2nodes\", \"root_password\": \"$(openssl rand -base64 16)\", \"root_ssh_key\": \"empty-key-no-root-ssh\", \"network2_defined\": false, \"network3_defined\": false }"

flight architect template
cp /var/lib/architect/clusters/gateway2nodes/var/rendered/kickstart/domain/platform/manifest.yaml /var/lib/architect/clusters/gateway2nodes/var/rendered/

