#!/bin/bash

# Install Flight Manage
yum -y install flight-manage

# Create scripts directory
NODEDIR=/opt/service/nodescripts/<%= node.name %>scripts
mkdir -p $NODEDIR
mkdir -p /opt/service/flight/managedata

# Download scripts
curl <%= config.renderedurl %>/core/plugins/flightdirect.bash > $NODEDIR/flightdirect.bash 
curl <%= config.renderedurl %>/core/plugins/nfs.bash > $NODEDIR/nfs.bash 
curl <%= config.renderedurl %>/core/plugins/slurm.bash > $NODEDIR/slurm.bash 

# Set executable
chmod +x -R $NODEDIR/*.bash
