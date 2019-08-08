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
ReturnToService=1
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
AccountingStorageLoc=/var/log/slurm/accounting
AccountingStorageType=accounting_storage/slurmdbd
JobAcctGatherType=jobacct_gather/linux
AccountingStorageHost=gateway1
NodeName=<%= groups.nodes.hostlist_nodes %>
PartitionName=all Nodes=ALL Default=YES MaxTime=UNLIMITED
EOF
`

<% if (node.config.gateway rescue false) -%>
# Build SLURM RPMs
yum -y install wget rpm-build munge munge-devel munge-libs perl-Switch numactl pam-devel perl-ExtUtils-MakeMaker mariadb-devel gcc readline-devel
cd /tmp/
wget https://download.schedmd.com/slurm/slurm-$VERSION.tar.bz2
rpmbuild -ta slurm-$VERSION.tar.bz2

mkdir -p /opt/repo/flight/packages
cp /root/rpmbuild/RPMS/x86_64/slurm-*.rpm /opt/repo/flight/packages/
cd /opt/repo
createrepo flight
<% end -%>

yum -y -e0 install munge munge-devel munge-libs perl-Switch numactl
yum --enablerepo flight -y -e 0 --nogpgcheck install slurm slurm-devel slurm-perlapi slurm-torque slurm-slurmd slurm-example-configs slurm-libpmi
<% if (node.config.gateway rescue false) -%>
yum -y -e0 install mariadb mariadb-test mariadb-libs mariadb-embedded mariadb-embedded-devel mariadb-devel mariadb-bench
yum --enablerepo flight -y --nogpgcheck install slurm-slurmctld slurm-slurmdbd
systemctl enable mariadb
systemctl enable slurmdbd
systemctl start mariadb

# Create spool directory
mkdir -p /var/spool/slurm.state
chown nobody:nobody /var/spool/slurm.state

# Setup DB account and permissions
mysql -uroot -e "create user 'slurm'@'localhost' identified by '';"
mysql -uroot -e "grant all on slurm_acct_db.* TO 'slurm'@'localhost';"
mysql -uroot -e "CREATE DATABASE slurm_acct_db;"

# Configure slurmdbd
cat << EOF > /etc/slurm/slurmdbd.conf
# Archive info
#ArchiveJobs=yes
#ArchiveDir="/tmp"
#ArchiveSteps=yes
#ArchiveScript=
#JobPurge=12
#StepPurge=1
#
# Authentication info
AuthType=auth/munge
#AuthInfo=/var/run/munge/munge.socket.2
#
# slurmDBD info
DbdAddr=localhost
DbdHost=localhost
#DbdPort=7031
SlurmUser=nobody
#MessageTimeout=300
DebugLevel=4
#DefaultQOS=normal,standby
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/var/run/slurmdbd.pid
#PluginDir=/usr/lib/slurm
#PrivateData=accounts,users,usage,jobs
#TrackWCKey=yes
#
# Database info
StorageType=accounting_storage/mysql
#StorageHost=localhost
#StoragePort=1234
StoragePass=""
StorageUser=slurm
#StorageLoc=slurm_acct_db
EOF

systemctl start slurmdbd

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
# Configure cluster and users
sacctmgr -i add cluster <%= config.domain %>
sacctmgr -i add account siteadmin Description="Site admin users"
sacctmgr -i create user name=flight-cluster DefaultAccount=siteadmin
sacctmgr -i modify user flight-cluster set adminlevel=admin
sacctmgr -i modify user siteuser set adminlevel=operator

systemctl enable slurmctld
systemctl start slurmctld
<% else -%>
systemctl enable slurmd
systemctl start slurmd
<% end -%>
