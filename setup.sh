#!/bin/bash
#
# This script will only need to be run once on a hub to prepare 
# cluster configurations for cloud
#

# Create SSH keypair
ssh-keygen -N '' -f /root/.ssh/id_rsa

# Get ansible playbook
yum -y install ansible
cd
git clone https://github.com/openflighthpc/openflight-ansible-playbook
