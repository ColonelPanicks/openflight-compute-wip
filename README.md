# OpenFlight Compute Cluster Builder

This repository contains scripts for the R&D setup of OpenFlight Compute.

The repo provides tools to:
- Setup a clean CentOS install to deploy clusters
- Build small openflight compute clusters in the cloud
- Destroy deployed clusters
- Verify which clusters are up and which have been deleted outside of the destroy script
- Generate assets for web-based VNC access to all currently running clusters

## Setup the Environment

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
    bash bin/setup.sh
    ```

5. Update the config variables to reflect desired cloud configuration

   ```
   vim configs/default.sh
   ```

## Create a Cluster

### Cluster Using Default Configuration

- Navigate to builder directory

    ```
    cd openflight-compute-cluster-builder
    ```

- Create a cluster, providing the name and public SSH key to use

    ```
    bash bin/build-cluster.sh CLUSTERNAME 'SSH PUBLIC KEY'
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

## Destroy Deployed Clusters

The `bin/destroy-cluster.sh` script works in a similar manner to the build cluster script. 

Destroying a cluster requires that the same config used to deploy the cluster be specified before the script.

The script will warn the user and safely exit if there are duplicate clusters existing with the same name.

## Verify Which Clusters Are Up

It's easy for the deployed cluster list (each cluster has an individual file under `/opt/flight/clusters`) to get out of sync with what's actually deployed (due to clusters usually being destroyed via cloud GUIs and not with the script).

The script `bin/check-clusters.sh` iterates through all the clusters under `/opt/flight/clusters` and tests ssh-ing into the gateway. A gateway that doesn't respond or doesn't authenticate is presumed as a destroyed cluster/reallocated IP address.

## Generate Web-Based VNC Access

The purpose of these scripts is to provide a central location for accessing VNC on multiple clusters (using NoVNC). This is beneficial for large bootcamp/OpenFlight demos where users bring their own laptops that could have issues with VNC software, terminal emulators and other unforeseen difficulties with connection.

There are 2 scripts to assist with this setup, they are:
- `bin/create-vnc-index.sh`
    - Creates a [token file](https://github.com/novnc/websockify/wiki/token-based-target-selection) for the websockify server
    - Creates a YAML with similar information to the token file for rendering the web index
    - Calls a ruby script to generate the index.html file from the YAML file
- `bin/generate-index.rb` 
    - Utilises ERB to generate an index.html file for hosting VNC connections`

## Versioning

The version release tags align with the tags in the openflight-ansible-playbook tags.
