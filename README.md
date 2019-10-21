# OpenFlight Compute WIP

This repository contains scripts for the R&D setup of OpenFlight Compute.

## How to Use It

Currently, this is being developed and tested on Azure.

1. Launch the latest Cloud Controller

2. Login and login to cloud CLI tools (`az login` / `aws configure`)

3. Clone the WIP repository

    ```
    git clone https://github.com/ColonelPanicks/openflight-compute-wip
    ```

4. Run the setup

    ```
    cd openflight-compute-wip
    bash setup.sh
    ```

5. Create a cluster

    ```
    cd openflight-compute-wip
    bash build-cluster.sh CLUSTERNAME 'SSH PUBLIC KEY'
    ```

Optionally, the number of compute nodes the cluster creates can be increased from 2 (the default and minimum value) to anything up to 8. Simply set the variable when building the cluster:

```
COMPUTENODES=4 bash build-cluster.sh CLUSTERNAME 'SSH PUBLIC KEY'
```

