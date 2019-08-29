#!/bin/bash
#FLIGHTdescription: Install SLURM
#FLIGHTstages: third

VERSION=18.08.7
MUNGEDIR=/data/
SLURMCONF=`cat << EOF
ClusterName=<%= config.domain %>
ControlMachine=gateway1
SlurmUser=nobody
SlurmctldPort=6817
SlurmdPort=6818
AuthType=auth/munge
StateSaveLocation=/var/spool/slurm.state
SlurmdSpoolDir=/var/spool/slurmd.spool
SwitchType=switch/none
MpiDefault=none
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
ProctrackType=proctrack/pgid
ReturnToService=2
SlurmctldTimeout=300
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0
SchedulerType=sched/backfill
SelectType=select/linear
FastSchedule=1
SlurmctldDebug=3
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=3
SlurmdLogFile=/var/log/slurm/slurmd.log
JobCompType=jobcomp/none
NodeName=<%= groups.nodes.hostlist_nodes %>
PartitionName=all Nodes=ALL Default=YES MaxTime=UNLIMITED
EOF
`

# Setup repo
curl https://openflighthpc-compute.s3.eu-west-2.amazonaws.com/slurm/openflight-slurm.repo > /etc/yum.repos.d/openflight-slurm.repo

yum -y -e0 install epel-release
yum -y -e0 install munge munge-devel munge-libs perl-Switch numactl
yum --enablerepo flight -y -e 0 --nogpgcheck install slurm slurm-devel slurm-perlapi slurm-torque slurm-slurmd slurm-example-configs slurm-libpmi
<% if (node.config.gateway rescue false) -%>
yum -y -e0 install mariadb mariadb-test mariadb-libs mariadb-embedded mariadb-embedded-devel mariadb-devel mariadb-bench
yum --enablerepo flight -y --nogpgcheck install slurm-slurmctld 

# Allow it all through the firewall
firewall-cmd --set-target ACCEPT --zone external --permanent
firewall-cmd --reload

systemctl enable mariadb
systemctl start mariadb

# Create spool directory
mkdir -p /var/spool/slurm.state
chown nobody:nobody /var/spool/slurm.state

cat << EOF > $MUNGEDIR/munge.key
$(dd if=/dev/urandom bs=1 count=1024)
EOF
<% end -%>

cp $MUNGEDIR/munge.key /etc/munge/
chmod 400 /etc/munge/munge.key
chown munge /etc/munge/munge.key

systemctl enable munge
systemctl start munge

mkdir /var/log/slurm
chown nobody /var/log/slurm

echo "$SLURMCONF" > /etc/slurm/slurm.conf

<% if (node.config.gateway rescue false) -%>
systemctl enable slurmctld
systemctl start slurmctld
<% else -%>
systemctl enable slurmd
systemctl start slurmd
<% end -%>
