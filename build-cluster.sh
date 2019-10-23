#!/bin/bash

#
# Run this script on a cloud controller
#

#############
# Variables #
#############

CLUSTERNAMEARG="$1"
SSH_PUB_KEY="$2"
PLATFORM="${PLATFORM:-azure}"
COMPUTENODES="${COMPUTENODES:-2}"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LOG="$DIR/log/deploy.log"

SEED=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6 ; echo '')
CLUSTERNAME="$CLUSTERNAMEARG-$SEED"

# The host IP which is sharing setup.sh script at IP/deployment/setup.sh
## Likely to be this machine
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

function deploy_azure() {
    az group create --name "$CLUSTERNAME" --location "$LOCATION"
    az group deployment create --name "$CLUSTERNAME" --resource-group "$CLUSTERNAME" \
        --template-file $DIR/templates/azure/cluster.json \
        --parameters sshPublicKey="$SSH_PUB_KEY" \
        sourceimage="$SOURCE_IMAGE" \
        controllerip="$CONTROLLERIP" \
        clustername="$CLUSTERNAME" \
        computeNodesCount="$COMPUTENODES"

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

function deploy_aws() {


}

function run_ansible() {
    # Run ansible playbook
    cd /root/openflight-ansible-playbook
    export ANSIBLE_HOST_KEY_CHECKING=false
    ansible-playbook -i /opt/flight/clusters/$CLUSTERNAME openflight.yml
}

#################
# Run Functions #
#################

case $PLATFORM in
    "azure")
        LOCATION="UK South"
        SOURCE_IMAGE="/subscriptions/d1e964ef-15c7-4b27-8113-e725167cee83/resourceGroups/alcesflight/providers/Microsoft.Compute/images/CENTOS7BASE2808191247"
        deploy_azure
    ;;
    "aws")
        LOCATION="eu-west-1"
        SOURCE_IMAGE=""
        deploy_aws
    ;;
esac


echo "$(date +'%Y-%m-%d %H-%M-%S') | $CLUSTERNAME | End Deploy | Gateway1 IP: $(az network public-ip show -g $CLUSTERNAME -n flightcloudclustergateway1pubIP --query "{address: ipAddress}" --output yaml |awk '{print $2}')" |tee -a $LOG
