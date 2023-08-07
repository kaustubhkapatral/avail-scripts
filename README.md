## One-click devnet for Avail

This folder contains tools to setup and destroy a local devnet for `avail`. The setup script installs the prerequisites, sets up the network and launches an explorer as well for easey testing. `purge-server.sh` script can be used to destroy the all the directories and artifacts that were created using the setup script.

### Usage 
```
bash single-server.sh 
```
This script will give out prompt to the user on how many validators and light clients it has to set up. If no values are provided it sets up 3 validators and 3 light clients by default. It also gives a prompt to the user on the tag or the absolute path of pre-built binaries that have to be used to start the network.

To shut down the network and remove all the setup files use the `purge-server.sh`

```
bash purge-server.sh
```
This script will give out prompt to the user on how many validators and light clients it has to shut down. If no values are provided it removes 3 validators and 3 light clients by default.
