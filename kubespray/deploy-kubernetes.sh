#!/bin/bash

# System update
sudo apt-get update && \
sudo apt-get upgrade

# SSH access
## Install SSH server
sudo apt-get install openssh-server

## Create SSH key pair
ssh-keygen -b 2048 -t rsa -f /home/adrien/.ssh/id_rsa -q -N ""

## Publish your public key on nodes
for ip in 192.168.1.3 192.168.1.78 192.168.1.118; do
  scp /home/adrien/.ssh/id_rsa.pub adrien@$ip:/home/adrien/.ssh
  ssh adrien@$ip "cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys && rm ~/.ssh/id_rsa.pub"
done

# IPv4 forwarding
# Will be done in prepare-cluster.yaml Ansible playbook

# Turn off swap
# Should be done by cluster.yaml Ansible playbook

# Get Kubespray
mkdir -p ~/projects/ && \
cd ~/projects/ && \
curl -L https://github.com/kubernetes-sigs/kubespray/archive/v2.12.5.tar.gz | tar xvz && \
mv kubespray-2.12.5 kubespray && \
cd kubespray

# Install Kubespray requirements
## Install Python 3
sudo apt-get install python3.7 python3-pip python3-venv

## Create a virtual env
python3 -m venv ~/projects/kubespray-venv
source ~/projects/kubespray-venv/bin/activate

## Install Kubespray dependencies
pip install -r requirements.txt

# Create a new cluster configuration
## Copy the sample
cp -rfp inventory/sample inventory/mycluster

## Use inventory builder
declare -a IPS=(192.168.1.3 192.168.1.78 192.168.1.118)
CONFIG_FILE=inventory/mycluster/hosts.yaml python contrib/inventory_builder/inventory.py ${IPS[@]}

## Rename nodes
sed -e 's/node1/tower/g' -e 's/node2/laptop/g' -e 's/node3/rpi/g'  -i inventory/mycluster/hosts.yaml

## Set Docker version since Ubuntu 19.10 is not supported
echo "docker_version: 19.03"  >> group_vars/all/docker.yaml

## Fix resol.conf since Ubuntu 19.10 is not supported
echo 'kube_resolv_conf: "/run/systemd/resolve/resolv.conf"' >> group_vars/all/all.yaml

# Deploy your cluster
## Deal with IPv4 forwarding
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root prepare-cluster.yml
## Run Kubespray playbook
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml
