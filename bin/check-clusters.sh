#!/bin/bash

#
# Use this script to check the contents of /opt/flight/clusters
# and remove any clusters that are no longer up/reachable (by SSH).
#

# Install nmap if not present
if ! rpm -qa |grep -q nmap ; then
    echo "Installing nmap"
    yum install -y nmap
fi

# Get directory of script for locating templates and config
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. >/dev/null 2>&1 && pwd )"

function check_up {
    IP=$(grep '^gateway1' /opt/flight/clusters/$cluster |sed 's/.*ansible_host=//g')
    if ! ssh -q -o ConnectTimeout=1 -o ConnectionAttempts=1 $IP exit > /dev/null; then
        echo "Cannot connect to $IP for SSH, presuming destroyed"
        rm -f /opt/flight/clusters/$cluster
    fi
}

for cluster in $(ls /opt/flight/clusters) ; do
    echo "Checking if $cluster gateway1 is up/reachable"
    check_up
done
