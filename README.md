# OpenFlight Compute Cluster Builder

This repository contains scripts for the R&D setup of OpenFlight Compute.

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

### Additional Notes

- If the variable `SSH_PUB_KEY` is present in a config file then it will be used. This value *will be overwritten if an SSH key is passed on the command line*.

## Versioning

The version release tags align with the tags in the openflight-ansible-playbook tags.
