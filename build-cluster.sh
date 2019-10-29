#!/bin/bash

#
# Run this script on a cloud controller
#

#############
# Variables #
#############

# Get directory of script for locating templates and config
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source variables
source $DIR/config.sh

CLUSTERNAMEARG="$1"
SSH_PUB_KEY="$2"

LOG="$DIR/log/deploy.log"

SEED=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6 ; echo '')
CLUSTERNAME="$CLUSTERNAMEARG-$SEED"

# The host IP which is sharing setup.sh script at http://IP/deployment/setup.sh
CONTROLLERIP=$(dig +short myip.opendns.com @resolver1.opendns.com)

#################
# Checking Args #
#################

if [ -z "${CLUSTERNAME}" ] ; then
    echo "Provide cluster name"
    echo "  build-cluster.sh CLUSTERNAME SSH_PUB_KEY"
    exit 1
elif [ -z "${SSH_PUB_KEY}" ] ; then
    echo "Provide ssh public key"
    echo "  build-cluster.sh CLUSTERNAME SSH_PUB_KEY"
    exit 1
elif [ "$COMPUTENODES" -lt 2 -o "$COMPUTENODES" -gt 8 ] ; then
    echo "Number of nodes must be between 2 and 8"
    exit 1
fi

# Don't allow SSH_PUB_KEY to be set to the controller's pub key (as this is added via setup.sh on the deployed nodes)
if [[ *"$(cat /root/.ssh/id_rsa.pub)"* == *"$SSH_PUB_KEY"* ]] ; then
    echo "Provide ssh public key that is *not* this controller's public key."
    echo "This controller's key is automatically added to the compute nodes at deployment"
    echo "to allow ansible setup to run on nodes"
    exit 1
fi

###############
# Log Details #
###############
echo "$(date +'%Y-%m-%d %H-%M-%S') | $CLUSTERNAME | Start Deploy | $PLATFORM | $SSH_PUB_KEY" |tee -a $LOG

#############
# Functions #
#############

function check_azure() {
    # Azure variables are non-empty
    if [ -z "${AZURE_SOURCEIMAGE}" ] ; then
        echo "AZURE_SOURCEIMAGE is not set in config.sh"
        echo "Set this before running script again"
        exit 1
    elif [ -z "${AZURE_LOCATION}" ] ; then
        echo "AZURE_LOCATION is not set in config.sh"
        echo "Set this before running script again"
        exit 1
    fi

    # Azure login configured
    if ! az account show > /dev/null 2>&1 ; then
        echo "Azure account not connected to CLI"
        echo "Run az login to connect your account"
        exit 1
    fi
}

function deploy_azure() {
    az group create --name "$CLUSTERNAME" --location "$AZURE_LOCATION"
    az group deployment create --name "$CLUSTERNAME" --resource-group "$CLUSTERNAME" \
        --template-file $DIR/templates/azure/cluster.json \
        --parameters sshPublicKey="$SSH_PUB_KEY" \
        sourceimage="$AZURE_SOURCEIMAGE" \
        controllerip="$CONTROLLERIP" \
        clustername="$CLUSTERNAME" \
        computeNodesCount="$COMPUTENODES" \
        customdata="$(cat $DIR/templates/cloudinit.txt |base64)"

    # Create ansible hosts file
    mkdir -p /opt/flight/clusters
    cat << EOF > /opt/flight/clusters/$CLUSTERNAME
[gateway]
gateway1    ansible_host=$(az network public-ip show -g $CLUSTERNAME -n flightcloudclustergateway1pubIP --query "{address: ipAddress}" --output yaml |awk '{print $2}')

[nodes]
$(i=1 ; while [ $i -le $COMPUTENODES ] ; do
echo "node0$i    ansible_host=$(az network public-ip show -g $CLUSTERNAME -n flightcloudclusternode0$i\pubIP --query '{address: ipAddress}' --output yaml |awk '{print $2}')"
i=$((i + 1))
done)
EOF
    
    # Customise nodes
    run_ansible
}

#function deploy_aws() {
#
#
#}

function run_ansible() {
    # Run ansible playbook
    cd /root/openflight-ansible-playbook
    export ANSIBLE_HOST_KEY_CHECKING=false
    ansible-playbook -i /opt/flight/clusters/$CLUSTERNAME --extra-vars "cluster_name=$CLUSTERNAMEARG munge_key=$( (head /dev/urandom | tr -dc a-z0-9 | head -c 18 ; echo '') | sha512sum | cut -d' ' -f1) compute_nodes=node[01-0$COMPUTENODES]" openflight.yml
}

#################
# Run Functions #
#################

case $PLATFORM in
    "azure")
        check_azure
        deploy_azure
    ;;
    "aws")
        deploy_aws
    ;;
esac


echo "$(date +'%Y-%m-%d %H-%M-%S') | $CLUSTERNAME | End Deploy | Gateway1 IP: $(az network public-ip show -g $CLUSTERNAME -n flightcloudclustergateway1pubIP --query "{address: ipAddress}" --output yaml |awk '{print $2}')" |tee -a $LOG
