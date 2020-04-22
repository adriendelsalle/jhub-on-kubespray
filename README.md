## Table of Contents
1. [Configuration used for this tutorial](#Configuration)
2. [Install Kubernetes using Kubespray](#Install-Kubernetes-using-Kubespray)
   1. [System update](#system-update)
   2. [Enable SSH using keys](#Enable-SSH-using-keys)
   3. [IPv4 forwarding](#IPv4-forwarding)
   4. [Turn off swap](#turn-off-swap)
   3. [Get Kubespray](#Get-Kubespray)
   4. [Install Kubespray requirements](#Install-Kubespray-requirements)
   5. [Create a new cluster configuration](#Create-a-new-cluster-configuration)
   6. [Deploy your cluster!](#Deploy-your-cluster!)
3. [Still missing in your cluster](#still-missing-in-your-cluster)
   1. [Load balancer](#load-balancer)
   2. [StorageClass and provider](#storageclass-and-provider)
4. [Install JupyterHub](#install-jupyterhub)
   1. [Install Helm]()
   2. [Deploy JupyterHub from Helm chart]()
5. [Enjoy!](#enjoy)

---
## Configuration

This tutorial is about running a JupyterHub instance on a kube cluster deployed with kubespray on bare metal.

- Hardware: 
  - CPU: 2 preferable
  - RAM: 1024MB/1500MB for worker/master nodes recommended, configurable in kubespray
- O/S: Ubuntu 19.10 Eoan
- Kubespray: 2.12.5
- Python: 3.7
- Helm: 3.1.2

> Note that Ubuntu 19.10 Eoan is not a [Kubespray supported linux distribution](https://github.com/kubernetes-sigs/kubespray#supported-linux-distributions). It requires a patch described [here](#then-customize-your-new-cluster). 

[[Top]](#table-of-contents)

---
## Install Kubernetes using Kubespray

These steps are in order to fulfill the Kubespray [requirements](https://github.com/kubernetes-sigs/kubespray#requirements).

### System update

It's always a good pratice to start with a system update.

``` bash
sudo apt-get update && \
sudo apt-get upgrade
```

> Do this on your localhost (used to run Kubespray).
> Kubespray will take care of system updates on the declared nodes.

[[Top]](#table-of-contents)

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
[[Top]](#table-of-contents)

### IPv4 forwarding

Kubespray requires to turn on IPv4 forwarding. This should be done automatically by Kubepsray.

To do it manually, run as sudo:

``` bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```

[[Top]](#table-of-contents)

### Turn off swap

It is required by kubernetes.
See : https://github.com/kubernetes/kubernetes/issues/53533

``` bash
swapoff -a && sed -i 'swap / s/^/#/' /etc/fstab
```

> You can use instead the `prepare-cluster.yaml` playbook set up in this tutorial

[[Top]](#table-of-contents)

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

[[Top]](#table-of-contents)

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

[[Top]](#table-of-contents)

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

[[Top]](#table-of-contents)

### Deploy your cluster!

- Check localhost vs nodes usernames

If your localhost username differ from a node username (the one that owns your SSH public key), you must specify it to Ansible by editing (manually) the hosts.yaml file.

Example:

| localhost username | node1 username |
| :----------------: |:--------------:|
| foo                | bar            |

``` bash
> cat inventory/mycluster/hosts.yaml
all:
  hosts:
    node1:
      ansible_ssh_user: bar
```

- Do the deployment by running Ansible playbook command.

``` bash
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml
```

[[Top]](#table-of-contents)

---
## Still missing in your cluster

### Load balancer

JupyterHub will expose a service waiting for a `Load balancer` to get and redirect traffic.
It will be achieve on our bare metal Kubernetes cluster using MetalLB.

[[Top]](#table-of-contents)

### StorageClass and provider

JupyterHub will need disk space to write Hub user database as well as the user workspaces.

- In-memory option

You can run JupyterHub with *in-memory* data but in this case you will lose all your data in case of cluster reboot, etc.

From JHub doc:
> Use an in-memory sqlite database. This should only be used for testing, since the database is erased whenever the hub pod restarts - causing the hub to lose all memory of users who had logged in before.

> When using this for testing, make sure you delete all other objects that the hub has created (such as user pods, user PVCs, etc) every time the hub restarts. Otherwise you might run into errors about duplicate resources.

Add to your `config.yaml` file some additional configuration.
``` bash
> cat config.yaml
proxy:
  secretToken: "<your-token>"

hub:
  db:
    type: sqlite-memory

singleuser:
  storage:
    type: sqlite-memory
```

- PV (persistent volume)

The default behaviour of JupyterHub is to create a Persistent Volume Claim PVC, waiting to the fulfilled by a PV in your Kubernetes cluster.

You now have to create the PV! In this tutorial, you will use a NFS one.

[[Top]](#table-of-contents)

---
## Install JupyterHub

---
## Enjoy!

I hope this tutorial was helpful!
Do not hesitate to make PR and have a great moment on JHub.
