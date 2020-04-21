A tutorial for a JupyterHub instance on a kube cluster deployed with kubespray on bare metal.

---
# Table of Contents
1. [Configuration used for this tutorial](#Configuration)
2. [Bootstrap the O/S](#Bootstrap-OS)
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

> Note that Ubuntu 19.10 Eoan is not a [Kubespray supported linux distribution](https://github.com/kubernetes-sigs/kubespray#supported-linux-distributions). It requires a patch described [here](#then-customize-your-new-cluster). 

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
mkdir -p ~/projects/ && \
cd ~/projects/ && \
curl -L https://github.com/kubernetes-sigs/kubespray/archive/v2.12.5.tar.gz | tar xvz && \
mv kubespray-2.12.5 kubespray && \
cd kubespray
```
> The kubespray directory is renamed without version number to have generic code below.

### Install Kubespray requirements

Install Kubespray requirements in a Python 3 environnement.

- Install Python 3

Also install pip (package installer for Python) and venv to create virtual environnement (see below).

``` bash
sudo apt-get install python3.7 python3-pip python3-venv
```

- Create a virtual env to segregate your workspace

``` bash
python3 -m venv ~/projects/kubespray-venv
source ~/projects/kubespray-venv/bin/activate
```

- Install Kubespray dependencies

``` bash
# Install dependencies from ``requirements.txt``
pip install -r requirements.txt
```

### Create a new cluster configuration

First copy the default settings from sample cluster.

``` bash
# Copy ``inventory/sample`` as ``inventory/mycluster``
cp -rfp inventory/sample inventory/mycluster
```
> Be sure you are still in the ~/projects/kubespray/ directory before executing this command!

Then customize your new cluster

- Update Ansible inventory file with inventory builder

``` bash
declare -a IPS=(<node1-ip> <node2-ip> ...)
CONFIG_FILE=inventory/mycluster/hosts.yaml python contrib/inventory_builder/inventory.py ${IPS[@]}
```
- (optional) Rename your nodes or deactivate hostname renaming

If not done, your cluster nodes will be named node1, node2, etc.

Edit file ~/projects/kubespray/inventory/mycluster/hosts.yaml

``` bash
sed -e 's/node1/tower/g' -e 's/node2/laptop/g' ... -i inventory/mycluster/hosts.yaml
```

OR

Keep the current hostnames

``` bash
echo "override_system_hostname: false" >>  group_vars/all/all.yaml
```

- Set Docker version to 19.03, since 18.09 is not available in apt sources

``` bash
echo "docker_version: 19.03"  >> group_vars/all/docker.yaml
```

- Set resolv.conf to the right file, only fixed for Ubuntu 18.* since 19.* are not supported.

See https://github.com/kubernetes-sigs/kubespray/pull/3335

``` bash
echo 'kube_resolv_conf: "/run/systemd/resolve/resolv.conf"' >> group_vars/all/all.yaml
```

### Deploy your cluster!

Do the deployment by running Ansible playbook command.

``` bash
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml
```
