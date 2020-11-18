#!/bin /bash

# install cfssl
wget -q --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl
chmod +x cfssl
sudo mv cfssl /usr/local/bin/

# install cfssljson
wget -q --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson
chmod +x cfssljson
sudo mv cfssljson /usr/local/bin/
