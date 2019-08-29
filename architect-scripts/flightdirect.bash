#!/bin/bash
#FLIGHTdescription: Install Flight Direct
#FLIGHTstages: second

VERSION=2.1.4

unset RUBYLIB RUBYOPT
unset $(env | grep ^BUNDLE | cut -f1 -d=)

curl -L https://raw.githubusercontent.com/alces-software/flight-direct/master/scripts/bootstrap.sh | bash -s $VERSION
source /etc/profile

unset RUBYLIB RUBYOPT
unset $(env | grep ^BUNDLE | cut -f1 -d=)

<% if (node.config.gateway rescue false) -%>
ROLE=login
<% else -%>
ROLE=compute
<% end -%>

flight config set role=$ROLE clustername=$NAMETEXT

# Patch flight-direct
## Download patches
mkdir -p /opt/flight-direct/patches
cat << 'EOF' > /opt/flight-direct/patches/post1.patch
diff --git a/bin/alces b/bin/alces
index e82908a..a142d00 100755
--- a/bin/alces
+++ b/bin/alces
@@ -1,2 +1,3 @@
 #!/bin/bash -l
-flight "$@"
+source /opt/flight-direct/etc/runtime.sh
+/opt/flight-direct/bin/flight "$@"
diff --git a/etc/clusterware.rc b/etc/clusterware.rc
index d786777..e8cdcab 100644
--- a/etc/clusterware.rc
+++ b/etc/clusterware.rc
@@ -1,4 +1,4 @@
 #
 # This config is only included becauses gridware expects it to exist
 #
-
+cw_VERSION=2.0.0
EOF

cat << 'EOF' > /opt/flight-direct/patches/post2.patch
--- etc/modules-alces.tcl.orig	2017-11-30 13:10:31.979589216 +0000
+++ etc/modules-alces.tcl	2019-06-05 13:13:35.807050308 +0100
@@ -4,6 +4,7 @@
 ## Copyright (c) 2008-2015 Alces Software Ltd
 ##
 ################################################################################
+
 namespace eval ::alces {
     namespace ensemble create
     namespace export once getenv try-deeper try-next pretty
@@ -143,7 +144,9 @@
 	variable ok
 	set original_branch [alces getenv cw_INTERNAL_BRANCH]
 	set original_trunk [alces getenv cw_INTERNAL_TRUNK]
-	processing
+	if { [processing] == 1 } {
+	    return
+	}
 	if { [info exists ::env(cw_INTERNAL_PROCESSING)] == 0 } {
 	    set ::env(cw_INTERNAL_PROCESSING) true
 	    set original_processing 1
@@ -222,10 +225,10 @@
         }
         if { [is-loaded ${m}] == 1 } {
             puts stderr " ... $skipped (already loaded)"
-            break
+	    return 1
         } elseif { [alt-is-loaded ${m}] == 1 } {
             puts stderr " ... $alt (have alternative: [alces pretty $::env(cw_INTERNAL_ALT)])"
-            break
+	    return 1
         } else {
             puts stderr ""
         }
EOF

cat << 'EOF' > /opt/flight-direct/patches/post3.patch
diff -urw bin.orig/alces bin/alces
--- bin.orig/alces	2019-05-10 18:59:54.671821022 +0100
+++ bin/alces	2019-08-07 15:46:30.000000000 +0100
@@ -1,3 +1,3 @@
-#!/bin/bash -l
+#!/bin/bash
 source /opt/flight-direct/etc/runtime.sh
 /opt/flight-direct/bin/flight "$@"
diff -urw bin.orig/flight bin/flight
--- bin.orig/flight	2018-10-25 11:49:10.000000000 +0100
+++ bin/flight	2019-08-07 15:48:39.000000000 +0100
@@ -22,7 +22,7 @@
 # For more information on the Alces Cloudware, please visit:
 # https://github.com/alces-software/cloudware
 #==============================================================================
-
+$VERBOSE = nil
 require_relative File.join("#{ENV["FL_ROOT"]}/lib/flight_direct.rb")

 # Runs the CLI
EOF

## Apply patches
echo "Applying patches"
cd /opt/flight-direct/
patch -r - -N -p1 < /opt/flight-direct/patches/post1.patch
patch -r - -N -p0 < /opt/flight-direct/patches/post2.patch
patch -r - -N -p0 < /opt/flight-direct/patches/post3.patch
echo "Finished patching"

# Install role
export ALCES_CONFIG_PATH=/opt/flight-direct/etc:/opt/gridware/etc # Because compute node installs will find /opt/gridware config first (due to login share) and therefore fail with volatile stuff and it'll be a real PITA
flight forge install flight-$ROLE

<% if (node.config.gateway rescue false) -%>
# Enable sessions
flight session enable base/gnome

# Allow root SSH login
mkdir -p /home/centos/.ssh/
echo "$USERSSHKEY" >> /home/centos/.ssh/authorized_keys
chmod 600 /home/centos/.ssh/authorized_keys
chown -R centos:centos /home/centos

# Add centos user to gridware group
usermod -a -G gridware centos 

# Whitelist user to install everything
cat << EOF > /opt/gridware/etc/whitelist.yml
:users:
- centos
EOF
<% end -%>

# Add OpenFlight branding
curl https://openflighthpc-compute.s3.eu-west-2.amazonaws.com/banner/openflight.sh > /opt/flight-direct/scripts/openflight.sh
chmod +x /opt/flight-direct/scripts/openflight.sh
sed -i 's,scripts/moosebird,scripts/openflight,g' /opt/flight-direct/etc/profile.d/01-banner.sh

# Enable storage types
flight storage enable base/s3

# Install VTE for srun over terminal
yum install -y vte vte-profile

# Create genders file
cat << EOF > /opt/flight-direct/etc/genders
<% groups.each do |group| -%>
<% next if group.name == 'orphan' -%>
<%= group.hostlist_nodes %>    <%= "#{group.name},#{group.config.role},#{group.answer.secondary_groups},all".split(',').uniq.reject(&:empty?).join(',')  %>
<% end -%>
<% orphan_list.each do |node| -%>
<%= node %>    orphan
<% end -%>
EOF
