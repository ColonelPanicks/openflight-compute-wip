# OpenFlight Compute Cluster Builder

This repository contains scripts for the R&D setup of OpenFlight Compute.

## How to Use It

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

5. Update the config variables to reflect cloud configuration

   ```
   vim config.sh
   ```

5. Create a cluster

    ```
    cd openflight-compute-cluster-builder
    bash build-cluster.sh CLUSTERNAME 'SSH PUBLIC KEY'
    ```

## Versioning

The version release tags align with the tags in the openflight-ansible-playbook tags.
