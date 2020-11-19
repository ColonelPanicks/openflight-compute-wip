#!/bin/bash

#
# Run this script on a cloud controller
#

#############
# Variables #
#############

# Get directory of script for locating templates and config
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source application variables
source $DIR/settings.sh

# Source cluster config variables
if [ -z "${CONFIG}" ] ; then
    source $DIR/configs/default.sh
else
    config_path=$DIR/configs/$CONFIG.sh
    if [ -f $config_path ] ; then
        source $config_path
    else
        echo "Error loading $CONFIG"
        echo "Could not load $config_path"
        exit 1
    fi
fi

CLUSTERNAMEARG="$1"
SSH_PUB_KEY="${2:-$SSH_PUB_KEY}"
PASSWORD="${2:-$PASSWORD}"

LOG="$DIR/log/deploy.log"

SEED=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6 ; echo '')
CLUSTERNAME="$CLUSTERNAMEARG-$SEED"

GATEWAYIP="Unknown"

#################
# Checking Args #
#################

if [ -z "${CLUSTERNAME}" ] ; then
    echo "Provide cluster name"
    echo "  build-cluster.sh CLUSTERNAME SSH_PUB_KEY"
    exit 1
elif [ "$COMPUTENODES" -lt 2 -o "$COMPUTENODES" -gt 8 ] ; then
    echo "Number of nodes must be between 2 and 8"
    exit 1
fi

#############
# Functions #
#############

function check_key() { 
    if [ -z "${SSH_PUB_KEY}" ] ; then
        echo "Provide ssh public key"
        echo "  build-cluster.sh CLUSTERNAME SSH_PUB_KEY"
        exit 1
    fi

    if ! echo "$SSH_PUB_KEY" | ssh-keygen -lf /dev/stdin > /dev/null 2>&1 ; then
        echo "Invalid SSH key"
        echo "  The SSH key provided was not successfully validated by ssh-keygen"
        echo "  It is most likely that a character or symbol is missing from the key"
        echo "  Verify the key is correct and try running this script again"
        exit 1
    fi

    # Don't allow SSH_PUB_KEY to be set to the controller's pub key (as this is added via setup.sh on the deployed nodes)
    if [[ *"$(cat /root/.ssh/id_rsa.pub)"* == *"$SSH_PUB_KEY"* ]] ; then
        echo "Provide ssh public key that is *not* this controller's public key."
        echo "This controller's key is automatically added to the compute nodes at deployment"
        echo "to allow ansible setup to run on nodes"
        exit 1
    fi

}

function check_password() {
    if [ -z "${PASSWORD}" ] ; then
        echo "Provide ssh password"
        echo "  build-cluster.sh CLUSTERNAME PASSWORD"
        exit 1
    fi
}

function generate_custom_data() {
    DATA=$(cat << EOF
#cloud-config
system_info:
  default_user:
    name: flight
runcmd:
  - echo "$(cat /root/.ssh/id_rsa.pub)" >> /root/.ssh/authorized_keys
$(if [[ "$AUTH" == "key" ]] ; then
echo "  - echo "$SSH_PUB_KEY" >> /home/flight/.ssh/authorized_keys"
else
echo "  - echo "$PASSWORD" | passwd --stdin flight"
echo "  - sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
echo "  - systemctl restart sshd"
fi)
  - systemctl disable firewalld && systemctl stop firewalld
  - timedatectl set-timezone Europe/London
  - grep -q "$CLUSTERNAMEARG" /etc/resolv.conf || sed -ri 's/^search (.*?)( pri.$CLUSTERNAMEARG.cluster.local|$)/search \1 pri.$CLUSTERNAMEARG.cluster.local/' /etc/resolv.conf
EOF
)
    CUSTOMDATA=$(echo "$DATA" |base64 -w 0)
}

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
        --template-file $DIR/$AZURE_TEMPLATE \
        --parameters sourceimage="$AZURE_SOURCEIMAGE" \
        clustername="$CLUSTERNAMEARG" \
        computeNodesCount="$COMPUTENODES" \
        gatewayinstancetype="$AZURE_GATEWAYINSTANCE" \
        computeinstancetype="$AZURE_COMPUTEINSTANCE" \
        customdata="$CUSTOMDATA"

    GATEWAYIP=$(az network public-ip show -g $CLUSTERNAME -n flightcloudclustergateway1pubIP --query "{address: ipAddress}" --output yaml |awk '{print $2}')

    # Create ansible hosts file
    mkdir -p /opt/flight/clusters
    cat << EOF > /opt/flight/clusters/$CLUSTERNAME
[gateway]
gateway1    ansible_host=$GATEWAYIP

[nodes]
$(i=1 ; while [ $i -le $COMPUTENODES ] ; do
echo "node0$i    ansible_host=$(az network public-ip show -g $CLUSTERNAME -n flightcloudclusternode0$i\pubIP --query '{address: ipAddress}' --output yaml |awk '{print $2}')"
i=$((i + 1))
done)
EOF
    
    # Customise nodes
    run_customisation
}

function check_aws() {
    # Azure variables are non-empty
    if [ -z "${AWS_SOURCEIMAGE}" ] ; then
        echo "AWS_SOURCEIMAGE is not set in config.sh"
        echo "Set this before running script again"
        exit 1
    elif [ -z "${AWS_LOCATION}" ] ; then
        echo "AWS_LOCATION is not set in config.sh"
        echo "Set this before running script again"
        exit 1
    fi

    # Azure login configured
    if ! aws sts get-caller-identity > /dev/null 2>&1 ; then
        echo "AWS account not connected to CLI"
        echo "Run aws configure to connect your account"
        exit 1
    fi
}

function deploy_aws() {
    # Deploy resources
    aws cloudformation deploy --template-file $DIR/$AWS_TEMPLATE --stack-name $CLUSTERNAME \
        --region "$AWS_LOCATION" \
        --parameter-overrides sourceimage="$AWS_SOURCEIMAGE" \
        clustername="$CLUSTERNAMEARG" \
        computeNodesCount="$COMPUTENODES" \
        gatewayinstancetype="$AWS_GATEWAYINSTANCE" \
        computeinstancetype="$AWS_COMPUTEINSTANCE" \
        customdata="$CUSTOMDATA"
    aws cloudformation wait stack-create-complete --stack-name $CLUSTERNAME --region "$AWS_LOCATION"

    GATEWAYIP=$(aws cloudformation describe-stack-resources --region "$AWS_LOCATION" --stack-name $CLUSTERNAME --logical-resource-id flightcloudclustergateway1pubIP |grep PhysicalResourceId |awk '{print $2}' |tr -d , | tr -d \")

    # Create ansible hosts file
    mkdir -p /opt/flight/clusters
    cat << EOF > /opt/flight/clusters/$CLUSTERNAME
[gateway]
gateway1    ansible_host=$GATEWAYIP

[nodes]
$(i=1 ; while [ $i -le $COMPUTENODES ] ; do
echo "node0$i    ansible_host=$(aws cloudformation describe-stack-resources --region "$AWS_LOCATION" --stack-name $CLUSTERNAME --logical-resource-id flightcloudclusternode0$i\pubIP |grep PhysicalResourceId |awk '{print $2}' |tr -d , | tr -d \")"
i=$((i + 1))
done)
EOF

    # Customise nodes
    run_customisation
}

function run_customisation() {
    set_hostnames
    run_ansible
}

function set_hostnames() {
    NODES=$(grep -vE '^\[|^$' /opt/flight/clusters/$CLUSTERNAME)

    # Loop through nodes and set hostname
    while IFS= read -r node ; do
        name=$(echo "$node" |awk '{print $1}')
        ip=$(echo "$node" |awk '{print $2}' |sed 's/.*ansible_host=//g')

        until ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no $ip exit </dev/null 2>/dev/null ; do
            sleep 5
        done
        ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no $ip "hostnamectl set-hostname $name.pri.$CLUSTERNAMEARG.cluster.local" </dev/null
    done <<< "$(echo "$NODES")"
}

function run_ansible() {
    # Determine if dev repos for openflight to be used
    if [ "$FLIGHTENVDEV" = "true" ] ; then
        flightenv_dev_var="flightenv_dev=true"
    fi

    # Determine if extra flight env stuff to be run
    if [ "$FLIGHTENVPREPARE" = "true" ] ; then
        flightenv_bootstrap_var="flightenv_bootstrap=true"
    fi

    # Run ansible playbook
    cd $ANSIBLE_PLAYBOOK_DIR
    export ANSIBLE_HOST_KEY_CHECKING=false
    ansible-playbook -i /opt/flight/clusters/$CLUSTERNAME --extra-vars "cluster_name=$CLUSTERNAMEARG munge_key=$( (head /dev/urandom | tr -dc a-z0-9 | head -c 18 ; echo '') | sha512sum | cut -d' ' -f1) compute_nodes=node[01-0$COMPUTENODES] $flightenv_dev_var $flightenv_bootstrap_var" openflight.yml
}

#################
# Run Functions #
#################

case $AUTH in 
    "key")
        check_key
    ;;
    "password")
        check_password
    ;;
    *)
        echo "Unrecognised auth type ($AUTH)"
        echo "Set to either 'key' or 'password'"
        exit 1
    ;;
esac

echo "$(date +'%Y-%m-%d %H-%M-%S') | $CLUSTERNAME | Start Deploy | $PLATFORM | Auth Method: $AUTH" |tee -a $LOG

generate_custom_data

case $PLATFORM in
    "azure")
        check_azure
        deploy_azure
    ;;
    "aws")
        check_aws
        deploy_aws
    ;;
    *)
        echo "Unknown platform"
    ;;
esac


echo "$(date +'%Y-%m-%d %H-%M-%S') | $CLUSTERNAME | End Deploy | Gateway1 IP: $GATEWAYIP" |tee -a $LOG
