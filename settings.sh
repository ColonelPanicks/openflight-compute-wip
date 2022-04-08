# Directory containing the OpenFlight Ansible Playbook
ANSIBLE_PLAYBOOK_DIR=/root/openflight-ansible-playbook

# Cloud Templates (paths must be relative path to the builder install directory)
AZURE_TEMPLATE=templates/azure/cluster.json
AWS_TEMPLATE=templates/aws/cluster.yaml

# FQDN for platforms
## See the README for more information on what these are and how to set them up
AWS_DOMAIN=""
AZURE_DOMAIN=""
AZURE_DOMAIN_RG=""
