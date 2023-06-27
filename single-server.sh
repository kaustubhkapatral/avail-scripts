#!/bin/bash

function color() {
    # Usage: color "31;5" "string"
    # Some valid values for color:
    # - 5 blink, 1 strong, 4 underlined
    # - fg: 31 red,  32 green, 33 yellow, 34 blue, 35 purple, 36 cyan, 37 white
    # - bg: 40 black, 41 red, 44 blue, 45 purple
    printf '\033[%sm%s\033[0m\n' "$@"
}

# Take the basic deployments arguments from the user.

#echo "Please enter the tag of the node version to be deployed"
#read TAG_VERSION

color "33" "Please enter the number of validator nodes you want to deploy.[default=3]" 

read VAL_COUNT
if [ -z $VAL_COUNT ]
then
    VAL_COUNT=3
fi

color "33" "Please enter the number of light clients nodes you want to deploy.[default=3]"

read LIGHT_COUNT
if [ -z $LIGHT_COUNT ]
then
    LIGHT_COUNT=3
fi

color "32" "Setting up $VAL_COUNT validators and $LIGHT_COUNT light clients. Press ENTER to proceed or Ctrl+c to exit the setup"
read


if ! command -v data-avail &> /dev/null
then
    echo "data-avail could not be found"
fi

if ! command -v jq &> /dev/null
then
    echo "jq could not be found"
fi

# Keys creation
color "33" "Setting up sudo, tech-committee and validators accounts and creating their keys"
sleep 4

mkdir $HOME/avail-keys

for (( i=1; i<=$VAL_COUNT; i++ ))
do 
    echo "validator-$i" >> $HOME/avail-keys/nodecount.txt
done

echo "election-01" >> $HOME/avail-keys/nodecount.txt
echo "sudo-01" >> $HOME/avail-keys/nodecount.txt
echo "tech-committee-01" >> $HOME/avail-keys/nodecount.txt
echo "tech-committee-02" >> $HOME/avail-keys/nodecount.txt
echo "tech-committee-03" >> $HOME/avail-keys/nodecount.txt 

cat $HOME/avail-keys/nodecount.txt | while IFS= read -r node_name; do
    printf 'Generating keys for %s\n' "$node_name"
    data-avail key generate --output-type json --scheme Sr25519 -w 21 > $HOME/avail-keys/$node_name.wallet.sr25519.json
    cat $HOME/avail-keys/$node_name.wallet.sr25519.json | jq -r '.secretPhrase' > $HOME/avail-keys/$node_name.wallet.secret
    data-avail key generate-node-key 2> $HOME/avail-keys/$node_name.public.key 1> $HOME/avail-keys/$node_name.private.key
    data-avail key inspect --scheme Ed25519 --output-type json $HOME/avail-keys/$node_name.wallet.secret > $HOME/avail-keys/$node_name.wallet.ed25519.json
done

color "32" "Generated validator and tech-committee keys."
sleep 4

color "33" "Consolidating keys and building the chainspec"
sleep 4

python3 consolidate-keys.py $HOME/avail-keys

cp templates/genesis/devnet.template.json $HOME/avail-keys

python3 update-dev-chainspec.py $HOME/avail-keys

data-avail build-spec --chain=$HOME/avail-keys/populated.devnet.chainspec.json --raw --disable-default-bootnode > $HOME/avail-keys/populated.devnet.chainspec.raw.json

CHAIN_NAME=$(cat $HOME/avail-keys/populated.devnet.chainspec.raw.json | jq -r .id)

color "32" "Generated the chainspec. Chain id of the devnet is $CHAIN_NAME"
sleep 4

color "33" "Creating validator home directories and importing keys"
sleep 4

mkdir -p $HOME/avail-home/avail-validators

for (( i=1; i<=$VAL_COUNT; i++ ))
do 
    mkdir -p $HOME/avail-home/avail-validators/validator-$i/chains/$CHAIN_NAME/network
    cp $HOME/avail-keys/validator-$i.private.key $HOME/avail-home/avail-validators/validator-$i/chains/$CHAIN_NAME/network/secret_ed25519
    data-avail key insert --base-path $HOME/avail-home/avail-validators/validator-$i --chain $HOME/avail-keys/populated.devnet.chainspec.raw.json --scheme Sr25519 --suri "$(cat $HOME/avail-keys/validator-${i}.wallet.secret)" --key-type babe
    data-avail key insert --base-path $HOME/avail-home/avail-validators/validator-$i --chain $HOME/avail-keys/populated.devnet.chainspec.raw.json --scheme Ed25519 --suri "$(cat $HOME/avail-keys/validator-${i}.wallet.secret)" --key-type gran
    export NODE_KEY=$(cat $HOME/avail-keys/validator-$i.public.key)
    DIFF=$(($i - 1))
    INC=$(($DIFF * 2))
    RPC=$((26657 + $INC))
    P2P=$((30333 + $INC))
    echo "--bootnodes=/ip4/127.0.0.1/tcp/$P2P/p2p/$NODE_KEY" >> $HOME/avail-keys/bootnode.txt
done

color "33" "Created validator home directories and importing respective keys"
sleep 4

color "33" "Generating systemd service files for validators"
sleep 4

for (( i=1; i<=$VAL_COUNT; i++ ))
do
    DIFF=$(($i - 1))
    INC=$(($DIFF * 2))
    RPC=$((26657 + $INC))
    
    echo "[Unit]
    Description=Avail val ${i} daemon
    After=network.target
    [Service]
    Type=simple
    User=$USER
    ExecStart=$(which data-avail) --validator --allow-private-ipv4 --base-path $HOME/avail-home/avail-validators/validator-$i --rpc-port $RPC --chain $HOME/avail-keys/populated.devnet.chainspec.raw.json $(cat $HOME/avail-keys/bootnode.txt) 
    Restart=on-failure
    RestartSec=3
    LimitNOFILE=4096
    [Install]
    WantedBy=multi-user.target" | sudo tee "/etc/systemd/system/avail-val-${i}.service"

    #sudo systemctl enable avail-val-${i}.service
    sudo systemctl start avail-val-${i}.service
done

color "32" "Created and started avail validators systemd processes"
sleep 4

color "33" "Generating key and home directory for light client bootnode"
sleep 4

data-avail key generate-node-key 2> $HOME/avail-keys/light-client-boot.public.key 1> $HOME/avail-keys/light-client-boot.private.key
mkdir -p $HOME/avail-home/avail-light/light-1

echo "log_level = \"info\"
http_server_host = \"127.0.0.1\"
http_server_port = \"7000\"
libp2p_seed = 1
libp2p_port = \"37000\"
secret_key = { key =  \"$(cat $HOME/avail-keys/light-client-boot.private.key)\" }
full_node_rpc = [\"http://127.0.0.1:26657\"]
app_id = 0
confidence = 92.0
avail_path = \"$HOME/avail-home/avail-light/light-1\"
" | sudo tee "$HOME/avail-home/avail-light/light-1/config.yaml"

color "33" "Generating home directories for remaining light clients"
sleep 4

for (( i=2; i<=$LIGHT_COUNT; i++ ))
do
    mkdir -p $HOME/avail-home/avail-light/light-$i
    DIFF=$(($i - 1))
    INC=$(($DIFF * 2))
    P2P=$((37000 + $INC))
    PROM=$((9520 + $INC))
    HTTP=$((7000 + $INC))
    echo "log_level = \"info\"
http_server_host = \"127.0.0.1\"
http_server_port = \"$HTTP\"
libp2p_seed = 1
libp2p_port = \"$P2P\"
bootstraps = [[\"$(cat $HOME/avail-keys/light-client-boot.public.key)\", \"/ip4/127.0.0.1/tcp/3700\"]]
full_node_rpc = [\"http://127.0.0.1:26657\"]
app_id = 0
confidence = 92.0
prometheus_port = $PROM
avail_path = \"$HOME/avail-home/avail-light/light-$i\"
" | sudo tee "$HOME/avail-home/avail-light/light-$i/config.yaml" 
done

color "33" "Generating systemd service files for light clients"
sleep 4

for (( i=1; i<=$LIGHT_COUNT; i++ ))
do
    
    echo "[Unit]
    Description=Avail light ${i} daemon
    After=network.target
    [Service]
    Type=simple
    User=$USER
    ExecStart=$(which avail-light) -c  $HOME/avail-home/avail-light/light-$i/config.yaml
    Restart=on-failure
    RestartSec=3
    LimitNOFILE=4096
    [Install]
    WantedBy=multi-user.target" | sudo tee "/etc/systemd/system/avail-light-${i}.service"

    #sudo systemctl enable avail-light-${i}.service
    sudo systemctl start avail-light-${i}.service
done
color "32" "Created and started avail light clients systemd processes"
sleep 4
color "32" "One-click devnet setup is now complete."
color "32" "Chain id of the devnet is $CHAIN_NAME"
color "32" "You can find all the keys at $HOME/avail-keys"
color "32" "You can find the home directories of validators and light clients at $HOME/avail-home"

sleep 4

for (( i=1; i<=$VAL_COUNT; i++ ))
do
    color "32" "You can find the logs of validator $i by executing 'sudo journalctl -u avail-val-${i}.service -f'"
    sleep 2
done

for (( i=1; i<=$LIGHT_COUNT; i++ ))
do
    color "32" "You can find the logs of light client $i by executing 'sudo journalctl -u avail-light-${i}.service -f'"
    sleep 2
done

