#!/bin/bash

#
# General Configuration
#

# Either 'azure' or 'aws'
PLATFORM="azure"
# A value between 2 and 8
COMPUTENODES="2"

# If true then the ansible-playbook will run additional
# configuration steps for the flight environment to ensure
# dependencies for the desktop and software environments
# are installed before users login
FLIGHTENVPREPARE=false

#
# Azure Configuration
#

# Example: /subscriptions/abcde123-4567-90ab-cdef-ghijklmnopqr/resourceGroups/MyResourceGroup/providers/Microsoft.Compute/images/CENTOS7BASE2808191247
AZURE_SOURCEIMAGE=""

# Example: "UK South"
AZURE_LOCATION=""


#
# AWS Configuration
#

# Example: ami-abcd123efgh5678
AWS_SOURCEIMAGE=""

# Example: "eu-west-1"
AWS_LOCATION=""
