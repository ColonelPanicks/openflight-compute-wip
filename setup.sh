#!/bin/bash
#
# This script will only need to be run once on a hub to prepare 
# cluster configurations for cloud
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

################
# Set Build IP #
################

IP="$(curl -f http://169.254.169.254/latest/meta-data/public-ipv4 2> /dev/null)"
if [ $? != 0 ] ; then
    ## Azure IP
    IP="$(curl -f -H Metadata:true 'http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2019-06-01&format=text' 2>/dev/null)"
fi


# Create SSH keypair
ssh-keygen -N '' -f /root/.ssh/id_rsa

# Create deployment script
cat << EOF > /opt/flight/deployment/setup.sh
#!/bin/bash

# Variables
CONTROLLER_SSH_PUB_KEY="$(cat /root/.ssh/id_rsa.pub)"

# Allow SSH from controller
echo "\$CONTROLLER_SSH_PUB_KEY" >> /root/.ssh/authorized_keys

# Get rid of pesky firewalls
firewall-cmd --remove-interface eth0 --zone public --permanent && firewall-cmd --add-interface eth0 --zone trusted --permanent && firewall-cmd --reload
EOF

# Create cloudinit script to replace deployment script
cat << EOF > $DIR/templates/cloudinit.txt
#cloud-config
runcmd:
  - echo "$(cat /root/.ssh/id_rsa.pub)" >> /root/.ssh/authorized_keys
  - firewall-cmd --remove-interface eth0 --zone public --permanent && firewall-cmd --add-interface eth0 --zone trusted --permanent && firewall-cmd --reload
  - timedatectl set-timezone Europe/London
EOF

# Get ansible playbook
yum -y install ansible
cd
git clone https://github.com/openflighthpc/openflight-ansible-playbook
