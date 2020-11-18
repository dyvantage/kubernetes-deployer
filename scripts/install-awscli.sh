#!/bin/bash

# install OS updates
sudo apt-get update

# install required packages
sudo apt-get install zip unzip

# install aws cli
curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip 2>/dev/null
unzip awscliv2.zip
sudo ./aws/install

exit 0
