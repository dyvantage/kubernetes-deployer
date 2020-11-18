#!/bin/bash

timezone="America/New_York"

usage() {
	echo "Usage: $(basename $0) <hostname>"
	exit 1
}

if [ $# -ne 1 ]; then usage; fi
hostname=${1}

# set hostname
sudo hostnamectl set-hostname ${hostname}

# setup time synchronization
sudo timedatectl set-timezone ${timezone}
sudo timedatectl set-ntp on

exit 0
