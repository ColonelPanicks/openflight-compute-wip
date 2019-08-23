# OpenFlight Compute WIP

This repository contains scripts for the R&D setup of OpenFlight Compute.


## How to Use It

Currently, this is being developed and tested on Azure.

1. Launch the latest OpenFlightHub

2. Login, configure cloud access credentials and name the default cluster (this cluster won't be used)

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

