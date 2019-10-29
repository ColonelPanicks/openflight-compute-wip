#!/bin/bash

#
# General Configuration
#

# Currently only Azure is supported
PLATFORM="azure"
# A value between 2 and 8
COMPUTENODES="2"


#
# Azure Configuration
#

# Example: /subscriptions/abcde123-4567-90ab-cdef-ghijklmnopqr/resourceGroups/MyResourceGroup/providers/Microsoft.Compute/images/CENTOS7BASE2808191247
AZURE_SOURCEIMAGE=""

# Example: "UK South"
AZURE_LOCATION=""

