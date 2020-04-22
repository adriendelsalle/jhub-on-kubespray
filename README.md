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
   2. [StorageClass and provisioner](#storageclass-and-provisioner)
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

JupyterHub will expose a service waiting for a `Load balancer` to get and redirect traffic to the right place.
It will be achieved on our bare metal Kubernetes cluster using MetalLB.

- Install MetalLB

Follow the [configuration guide](https://metallb.universe.tf/installation/).

``` bash
kubectl edit configmap -n kube-system kube-proxy
```

and set:

```
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

Then apply the manifests:

``` bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```

- Set MetalLB configuration

To allow the load balancer to distribute external IPs, you must specify in its configuration what is the IP chunk allocated for it.

It is done by applying the following [configuration file](https://metallb.universe.tf/configuration/#layer-2-configuration):

``` bash
kubectl apply -f metallb-config.yaml
```

with

``` bash
cat metallb-config.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - <your-ip-range>
```

> 
That's it!

[[Top]](#table-of-contents)

### StorageClass and provisioner

#### Introduction

JupyterHub will need disk space to write Hub users database as well as the users workspaces.

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

You now have to create the PV, or let a `provisioner` create it auto*magically* for you when a PVC requests a PV!

There are a lot of ways to create storage in Kubernetes, each one has avantages and drawbacks: some are only local, others cannot be dynamically provisionned, more/less difficult to implement, etc.

For more detailed information, please refer to the official Kubernetes documentation about [storage](https://kubernetes.io/docs/concepts/storage) that covers volumes/PV/PVC/provisioning/etc.

In this tutorial, you will use a `nfs` volume type for its simplicity, accessiblity between nodes and capability to be dynamically provisioned.

#### Set up the NFS server

From [Vitux tutorial](https://vitux.com/install-nfs-server-and-client-on-ubuntu/?__cf_chl_jschl_tk__=50c8eadb5fa04314c2916407c2751f68687aeb48-1587555276-0-AWkNR6Qizn6tsLLBsSUH1l_YOBi7OZLqRBXQzexN7S5FrW4QxNdSiOTwuRQaub2rjdraGI6zFVbGeKntmz-ZQW76uKjX4COBy5N14m8WXi0BRXvUlWDMxEvmlKs8iUrosn1-ctl7DoZlWbMWGIOFkGljgabLZv3CHBb0e-RpDRcUmuqFnv6Ct9PLcS2VGadHYKIuK5z9nKzU3qKACh3wHROeVhVH1Ibsel8NhqGCdPCWYBJn4EwR9WkUjFvf1Rycgv9751PotGabEq2l-_jipEoKgeo29yIk-uaWemKOPBiNvxjKhlZwNigfLGMAm4Mmuv6qWuGEKqQNKfLDjQjSRWwoSOqrRMbnXFs92AQCMt5knujCrI6RCDW699xX_fhnSmVjLDq_ra-BT3nVTRJV1D8).

  - Install NFS server

Just pick a machine on the same network as your cluster nodes (it can be one of them), and run:

``` bash
apt-get install -y nfs-kernel-server
```
  - Choose export directory
  
Choose or create a directory and share it:

``` bash
mkdir -p /mnt/my-nfs
```

As we want all clients to have access, change its permissions

``` bash
chown nobody:nogroup /mnt/my-nfs
chmod 777 /mnt/my-nfs
```

  - Do the NFS export

``` bash
echo "/mnt/my-nfs <subnetIP/24>(rw,sync,no_subtree_check)" >> /etc/exports
exportfs -a
systemctl restart nfs-kernel-server
```

> You have to replace `subnetIP/24` by a correct CIDR.

#### Define StorageClass and Provisioner

From [Yolanda tutorial](http://teknoarticles.blogspot.com/2018/10/setup-nfs-client-provisioner-in.html)

We will use [external-storage](https://github.com/kubernetes-incubator/external-storage] template.

- Set authorizations

``` bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs-client/deploy/rbac.yaml
```

- Set StorageClass

``` bash
kubectl apply -f nfs-storageclass.yaml
```

with

``` bash
> cat nfs-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
  annotations: 
    storageclass.kubernetes.io/is-default-class: true
provisioner: nfs-provisioner
parameters:
  archiveOnDelete: "false"
```

We declare the `StorageClass` as default one to automatically be selected by PVCs.

- Set Provisioner

``` bash
kubectl apply -f nfs-provisioner.yaml
```
with

``` bash
> cat nfs-provisoner.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: quay.io/external_storage/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: nfs-provisioner
            - name: NFS_SERVER
              value: <nfs-server-ip>
            - name: NFS_PATH
              value: /mnt/my-nfs
      volumes:
        - name: nfs-client-root
          nfs:
            server: <nfs-server-ip>
            path: /mnt/my-nfs
```

  - Check everything is OK
  
``` bash
kubectl get deployments.apps,pods,sc -n default
```

You should see the deployment of the `Provisioner`, the corresponding `Pod` and also the `StorageClass` as default one.

[[Top]](#table-of-contents)

---
## Install JupyterHub

---
## Enjoy!

I hope this tutorial was helpful!
Do not hesitate to make PR and have a great moment on JHub.
