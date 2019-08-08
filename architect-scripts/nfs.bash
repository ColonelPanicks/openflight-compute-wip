#!/bin/bash
#FLIGHTdescription: Configure NFS for cluster
#FLIGHTstages: first

yum -y install nfs-utils

<% if (node.config.gateway rescue false) -%>
# Create export directories
mkdir -p /export/data
mkdir -p /export/gridware
mkdir -p /export/users

# Increase nfsd thread count
sed -ie "s/^#\RPCNFSDCOUNT.*$/\RPCNFSDCOUNT=32/g" /etc/sysconfig/nfs

EXPORTOPTS="<%= config.networks.network1.network %>/<%= config.networks.network1.netmask %>(rw,no_root_squash,sync)"

EXPORTS=`cat << EOF
/export/data "$EXPORTOPTS"
/export/gridware "$EXPORTOPTS"
/export/users "$EXPORTOPTS"
EOF`

echo "$EXPORTS" > /etc/exports

firewall-cmd --add-service nfs --add-service mountd --add-service rpc-bind --zone external --permanent
firewall-cmd --reload
<% end -%>

MOUNTS=`cat << EOF
gateway1:/export/data   /data   nfs     intr,rsize=32768,wsize=32768,vers=3,_netdev     0 0
gateway1:/export/gridware   /opt/gridware   nfs     intr,rsize=32768,wsize=32768,vers=3,_netdev     0 0
gateway1:/export/users   /users   nfs     intr,rsize=32768,wsize=32768,vers=3,_netdev     0 0
EOF`

echo "$MOUNTS" >> /etc/fstab

mkdir -p /data /opt/gridware /users

systemctl enable nfs
systemctl restart nfs

<% if (node.config.gateway rescue false) -%>
exportfs -va
<% end -%>

mount -a
