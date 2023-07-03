#!/bin/bash

function color() {
    # Usage: color "31;5" "string"
    # Some valid values for color:
    # - 5 blink, 1 strong, 4 underlined
    # - fg: 31 red,  32 green, 33 yellow, 34 blue, 35 purple, 36 cyan, 37 white
    # - bg: 40 black, 41 red, 44 blue, 45 purple
    printf '\033[%sm%s\033[0m\n' "$@"
}


color "33" "Please enter the number of validator nodes that were deployed earlier.[default=3]"
read VAL_COUNT
if [ -z $VAL_COUNT ]
then
    VAL_COUNT=3
fi

color "33" "Please enter the number of light clients that were deployed earlier.[default=3]"
read LIGHT_COUNT
if [ -z $LIGHT_COUNT ]
then
    LIGHT_COUNT=3
fi

color "33" "Stopping and deleting the systemd files of validator service"
sleep 4 
for (( i=1; i<=$VAL_COUNT; i++ ))
do 
    sudo systemctl stop avail-val-${i}.service
    sudo systemctl disable avail-val-${i}.service
    sudo rm /etc/systemd/system/avail-val-${i}.service
done
color "32" "Purged the validator systemd files"
sleep 2

color "33" "Stopping and deleting the systemd files of light client service"
sleep 4 
for (( i=1; i<=$LIGHT_COUNT; i++ ))
do 
    sudo systemctl stop avail-light-${i}.service
    sudo systemctl disable avail-light-${i}.service
    sudo rm /etc/systemd/system/avail-light-${i}.service
done
color "32" "Purged the light client systemd files"
sleep 2

sudo systemctl stop avail-full.service

sudo rm /etc/systemd/system/avail-full.service

sudo systemctl daemon-reload

color "33" "Deleting the avail home and keys directories"

rm -rf $HOME/avail-home

rm -rf $HOME/avail-keys

color "32" "Purged the avail home and keys directories"
