## One-click devnet for Avail

This folder contains tools to setup and destroy a local devnet for `avail`. The setup script `single-server.sh` requires two arguments, `-n` and `-l` which are the [avail-node](https://github.com/availproject/avail/releases) and [avail-light](https://github.com/availproject/avail-light/releases) tags which need to be deployed. The setup script installs the prerequisites, does the sets up the network and launches an explorer as well for ease of testing. `purge-server.sh` script can be used to destroy the all the directories and artifacts that were created using the setup script.

### Usage 
```
# Setting up a network with v1.6.1-rc3 tag of avail and v1.4.3
 of avail-light
bash single-server.sh -n v1.6.1-rc3 -l v1.4.3
```
This script will give out prompt to the user on how many validators and light clients it has to set up. If no values are provided it sets up 3 validators and 3 light clients by default.

To shut down the network and remove all the setup files use the `purge-server.sh`

```
bash purge-server.sh
```
This script will give out prompt to the user on how many validators and light clients it has to shut down. If no values are provided it removes 3 validators and 3 light clients by default.

These scripts are WIP. Support for providing a precompiled binary to set up the network is currently in the works.