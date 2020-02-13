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

# Prepare websockify for VNC server
yum -y install novnc
git clone https://github.com/novnc/websockify /root/websockify

cat << EOF > /usr/lib/systemd/system/websockify-server.service
[Unit]
Description=Websockify VNC Server
Requires=network.target

[Service]
Type=simple
WorkingDirectory=/root/websockify
ExecStart=/root/websockify/run --web /usr/share/novnc/ --token-plugin TokenFile --token-source /root/tokens.list 0.0.0.0:8080

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

