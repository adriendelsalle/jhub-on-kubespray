# jhub-on-kubespray
A tutorial for a JupyterHub instance on a kube cluster deployed with kubespray

---
# Table of Contents
1. [Configuration used for this tutorial](#Configuration)
2. [Bootstrap the O/S](#Bootstrap-O/S)
3. [Install Kubernetes using Kubespray](#Install-Kubernetes-using-Kubespray)
   1. [Enable SSH using keys](#Enable-SSH-using-keys)
   2. [IPv4 forwarding](#IPv4-forwarding)
   3. [Get Kubespray](#Get-Kubespray)
   4. [Install Kubespray requirements](#Install-Kubespray-requirements)
   5. [Create a new cluster configuration](#Create-a-new-cluster-configuration)
   6. [Deploy your cluster!](#Deploy-your-cluster!)
   7. []()
4. [The missing parts of Kubernetes]()
   1. [Install a load balancer]()
   2. [StorageClass and provider]()
5. [Install JupyterHub]()
   1. [Install Helm]()
   2. [Deploy JupyterHub from Helm chart]()
6. [Enjoy!]()

---
## Configuration

- Hardware: 4 CPUs (amd64), 16GB RAM
- O/S: Ubuntu 19.10 Eoan
- Kubespray: 2.12.5
- Python: 3.7
- Helm: 3.1.2

> Note that Ubuntu 19.10 Eoan is not part of the [supported linux distribution](https://github.com/kubernetes-sigs/kubespray#supported-linux-distributions). It requires a patch described in 

---
## Bootstrap O/S

This tutorial is based on Linux distribution Ubuntu 19.10 Eoan.

- Turn off swap (req. by kubernetes)

``` bash
swapoff -a && sed -i 'swap / s/^/#/' /etc/fstab
```
see : https://github.com/kubernetes/kubernetes/issues/53533

- Update your system

It's always a good pratice to update your system.

``` bash
sudo apt-get update && \
sudo apt-get upgrade
```

---
## Install Kubernetes using Kubespray

These steps are in order to fulfill the Kubespray [requirements](https://github.com/kubernetes-sigs/kubespray#requirements).

### Enable SSH using keys

- Install SSH server

If a node does not have SSH server installed by default, you have to install it.
Ubuntu `server` images already have SSH server installed.

``` bash
sudo apt-get install openssh-server
```

  - Create SSH keys

You have to generate SSH keys pairs to allow Kubespray/Ansible automatic login using SSH.
You can use a different key for each node or use the same for all nodes.

``` bash
ssh-keygen -b 2048 -t rsa -f /home/<local-user>/.ssh/id_rsa -q -N ""
```

Copy the public part in the ~/.ssh/authorized_keys file of user you will use to login.
You will be asked for the password corresponding to <node-user> account, then you will never be asked again for password since SSH key will be used to authenticate.

``` bash
scp /home/<local-user>/.ssh/id_rsa.pub <node-user>@<node-ip>:/home/<node-user>/.ssh
ssh <node-user><node-ip> "cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys" "rm ~/.ssh/id_rsa.pub"
```

### IPv4 forwarding

IPv4 forwarding will be automatically turned on by Ansible playbook.

### Get Kubespray

Get Kubespray source code from its repo, prefer a stable release vs master.
Update the version number to latest available!

``` bash
curl -L https://github.com/kubernetes-sigs/kubespray/archive/v2.12.5.tar.gz | tar xvz && \
cd kubespray-2.12.5
```

### Install Kubespray requirements

Install Kubespray requirements in a Python 3 environnement.

We choose to use a Miniconda3 env:
- Download and install Miniconda3 : 


- Create a conda env

``` bash
conda create -y -n kubespray python=3.7 pip
conda activate kubespray
```

- Install Kubespray dependencies

``` bash
# Install dependencies from ``requirements.txt``
sudo pip3 install -r requirements.txt
```

### Create a new cluster configuration

First copy the default settings from sample cluster.

``` bash
# Copy ``inventory/sample`` as ``inventory/mycluster``
cp -rfp inventory/sample inventory/mycluster
```

Then customize your new cluster

``` bash
# Update Ansible inventory file with inventory builder
declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}

# Review and change parameters under ``inventory/mycluster/group_vars``

## Set Docker version to 19.03, since 18.09 is not available in apt sources
echo "docker_version: 19.03"  >> group_vars/all/docker.yaml
## Set resolv.conf to the right file, only fixed for Ubuntu 18.* by https://github.com/kubernetes-sigs/kubespray/pull/3335
echo 'kube_resolv_conf: "/run/systemd/resolve/resolv.conf"' >> group_vars/all/all.yaml
```

### Deploy your cluster!

Do the deployment by running Ansible playbook command.

``` bash
# Deploy Kubespray with Ansible Playbook - run the playbook as root
# The option `--become` is required, as for example writing SSL keys in /etc/,
# installing packages and interacting with various systemd daemons.
# Without --become the playbook will fail to run!
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml
```
