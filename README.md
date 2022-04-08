# OpenFlight Compute Cluster Builder

This repository contains scripts for the R&D setup of OpenFlight Compute.

## Cloud DNS Preparation

To support FQDNs for a custom domain on Azure & AWS a little bit of preparation is needed. The instructions below explain how to point a subdomain hosted externally to both platforms at the two platforms in order to allow for custom FQDNS.

The subdomains need to be set for both the `AWS_DOMAIN` and `AZURE_DOMAIN` application-wide settings in `settings.sh`. Additionally the `AZURE_DOMAIN_RG` needs to be set to the resource group where the DNS Zone exists. (_Note: these settings can be overridden on a per-config basis_)

### AWS

- Create public hosted zone in Route53 for the subdomain (e.g. `zone1.clusters.openflighthpc.org`)
- Create an NS record for the subdomain in the external DNS provider pointing to the Route53 nameservers 

### Azure

- Create public hosted zone in DNS Zones for the subdomain (e.g. `zone2.clusters.openflighthpc.org`)
- Create an NS record for the subdomain in the external DNS provider pointing to the Azure DNS Zone nameservers

## Configure Environment

Currently, this is being developed and tested on Azure.

1. Launch the latest Cloud Controller

2. Login to the controller and authorise cloud CLI tools (`az login` / `aws configure`)

3. Clone the cluster builder repository

    ```
    git clone https://github.com/openflighthpc/openflight-compute-cluster-builder
    ```

4. Run the setup (*Note: this will create an SSH keypair at /root/.ssh/id_rsa*)

    ```
    cd openflight-compute-cluster-builder
    bash setup.sh
    ```

5. Update the config variables to reflect desired cloud configuration

   ```
   vim configs/default.sh
   ```

6. Check/update the application settings

   ```
   cp settings.sh.example settings.sh
   ```

## Create a Cluster

### Cluster Using Default Configuration

- Navigate to builder directory

    ```
    cd openflight-compute-cluster-builder
    ```

- Create a cluster, providing the name and public SSH key to use

    ```
    bash build-cluster.sh CLUSTERNAME 'SSH PUBLIC KEY'
    ```

### Cluster Using Alternative Configuration

In some circumstances there are common deployment configurations that make constant management of one config file time-consuming and inflexible. For this reason, multiple configuration files can exist within `configs/` to allow for storage of these deployment details.

- Navigate to builder directory

    ```
    cd openflight-compute-cluster-builder
    ```

- Create a new config file

    ```
    cp configs/default.sh configs/mynewdeploymentconfig.sh
    ```

- Update variables and configuration to meet your requirements

   ```
   vim configs/mynewdeploymentconfig.sh
   ```

- Create a cluster, providing the name and public SSH key to use

    ```
    CONFIG=mynewdeploymentconfig bash build-cluster.sh CLUSTERNAME 'SSH PUBLIC KEY'
    ```

### Cluster Using Password Instead of SSH Key

While less secure, this method of authorising access to a cluster may be required from time to time. In order to switch from key authorisation to password, set the `AUTH` variable to `password` in the desired config file.

When `AUTH` is set to `password` the second argument to the build script will be used as the password instead of being used as an SSH public key.

### Additional Notes

- If the variable `SSH_PUB_KEY` is present in a config file then it will be used. *This value will be overwritten if an SSH key is passed on the command line*.
- If the variable `PASSWORD` is present in a config file then it will be used. *This value will be overwritten if a password is passed on the command line*.

## Cloud Init

The `build-cluster.sh` script creates a cloud-init string that will be run on all the nodes, the cloud-init config:
- Adds the build machine's SSH public key to all nodes (for passwordless remote access, required for running of ansible playbook)
- Sets up configured SSH public key/password access (depending on config) 
- Disables the firewall
- Disabled NetworkManager
- Sets the timezone to Europe/London
- Ensures that the cluster domain name is part of the search zone in `/etc/resolv.conf`

## Versioning

The version release tags align with the tags in the openflight-ansible-playbook tags.
