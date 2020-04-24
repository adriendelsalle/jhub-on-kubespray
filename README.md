## Table of Contents
1. [Introduction](#introduction)
2. [Configuration used for this tutorial](#Configuration)
3. [Install Kubernetes using Kubespray](#Install-Kubernetes-using-Kubespray)
   1. [System update](#system-update)
   2. [SSH access](#ssh-access)
   3. [IPv4 forwarding](#IPv4-forwarding)
   4. [Turn off swap](#turn-off-swap)
   3. [Get Kubespray](#Get-Kubespray)
   4. [Install Kubespray requirements](#Install-Kubespray-requirements)
   5. [Create a new cluster configuration](#Create-a-new-cluster-configuration)
   6. [Deploy your cluster!](#Deploy-your-cluster)
   7. [Access your cluster API](#access-your-cluster-api)
4. [Still missing in your cluster](#still-missing-in-your-cluster)
   1. [Set a `LoadBalancer`](#set-a-loadbalancer)
   2. [Set a `StorageClass` and a provisioner](#set-a-storageclass-and-a-provisioner)
5. [Install JupyterHub](#install-jupyterhub)
   1. [Install Helm](#install-helm)
   2. [Deploy JupyterHub from Helm chart](#deploy-jupyterhub-from-helm-chart)

---
## Introduction

This tutorial is about running a JupyterHub instance on a Kubernetes cluster deployed on bare metal.

For this purpose and after several attemps with Minikube and kubeadm, with and without VM, I choosed Kubespray using Ansible to deploy Kubernetes. It offers the performance of a bare metal cluster but also scalability and production-ready type of cluster.

[[Top]](#table-of-contents)

---
## Configuration

- Hardware: 
  - CPU: 2 preferable (no check)
  - RAM: 1024MB/1500MB minimum for worker/master nodes enforced in Kubespray (configurable)
- O/S: Ubuntu 19.10 Eoan
- Kubespray: 2.12.5
- Python: 3.7
- Helm: 3.1.2

> Note that Ubuntu 19.10 Eoan is not a [Kubespray supported linux distribution](https://github.com/kubernetes-sigs/kubespray#supported-linux-distributions). It requires a patch described [here](#then-customize-your-new-cluster). 

[[Top]](#table-of-contents)

---
## Install Kubernetes using Kubespray

Please follow these steps to fulfill the Kubespray [requirements](https://github.com/kubernetes-sigs/kubespray#requirements).

### System update

It's always a good pratice to start with a system update, especially before installing new packages.

``` bash
sudo apt-get update && \
sudo apt-get upgrade
```

> Do this on your localhost (used to run Kubespray).
> Kubespray will take care of system updates on the declared nodes.

[[Top]](#table-of-contents)

### SSH access

- Install SSH server

If a node does not have SSH a server installed by default, you have to install it to remotely connect this machine.
Ubuntu `server` O/Ss already have SSH a server installed.

``` bash
sudo apt-get install openssh-server
```

  - Create SSH key pair

You have to generate one or multiple SSH key pair(s) to allow Kubespray/Ansible automatic login using SSH.
You can use a different key pair for each node or use the same for all nodes.

``` bash
ssh-keygen -b 2048 -t rsa -f /home/<local-user>/.ssh/id_rsa -q -N ""
```

  - Copy your public key(s) on nodes
  
Copy your public key(s) in the ~/.ssh/authorized_keys file of the user accounts you will use on each node for deployment.
You will be prompted twice for the password corresponding to <node-user> account, the first time for the public key upload using SSH and the second time for adding the public key in the authorized keys file.
   
``` bash
for ip in <node1-ip> <node2-ip> ...; do
   scp /home/<local-user>/.ssh/id_rsa.pub <node-user>@$ip:/home/<node-user>/.ssh
   ssh <node-user>@$ip "cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys"
done
```

> You will never be prompted again for password using SSH, the key will be used to authenticate you!

[[Top]](#table-of-contents)

### IPv4 forwarding

Kubespray requires to turn on IPv4 forwarding. This should be done automatically by Kubepsray.

To do it manually, run the following command:

``` bash
for ip in <node1-ip> <node2-ip> ...; do
   ssh <node-user>@$ip "echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward"
done
```

[[Top]](#table-of-contents)

### Turn off swap

Turning swap off is required by Kubernetes. See this [issue](https://github.com/kubernetes/kubernetes/issues/53533) for more information.

``` bash
for ip in <node1-ip> <node2-ip> ...; do
   ssh <node-user>@$ip "sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab"
done
```

> This step can also be done using the `prepare-cluster.yaml` playbook available in this repo

[[Top]](#table-of-contents)

### Get Kubespray

Start by installing curl.

``` bash
sudo apt-get install curl
```

Get the lastest Kubespray source code from its repo. 

The latest release when writing this tutorial, v2.12.5, throws error not encountered in the master version.

> It is probably due to not supported Ubuntu 19.10 and will be fixed in 20.04!

``` bash
mkdir -p ~/projects/ && \
curl -LJO https://github.com/kubernetes-sigs/kubespray/archive/master.zip && \
unzip kubespray-master.zip -d kubespray && \
rm kubespray-master.zip && \
cd kubespray
```

[[Top]](#table-of-contents)

### Install Kubespray requirements

Kubespray uses Python 3 and several dependencies to be installed.

- Install Python 3

Install Python 3 but also pip (package installer for Python) and venv to create virtual environnements (see below).

``` bash
sudo apt-get install python3.7 python3-pip python3-venv
```

- Create a virtual env

This is a best isolation pratice using Python to use virtual env (or conda env for conda users).

``` bash
python3 -m venv ~/projects/kubespray-venv
source ~/projects/kubespray-venv/bin/activate
```

- Install Kubespray dependencies

``` bash
pip install -r requirements.txt
```

[[Top]](#table-of-contents)

### Create a new cluster configuration

Start creating a copy of the default settings from sample cluster.

``` bash
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

If you skip this step, your cluster hostnames will be renamed node1, node2, etc.

You can either edit the file ~/projects/kubespray/inventory/mycluster/hosts.yaml

``` bash
sed -e 's/node1/tower/g' -e 's/node2/laptop/g' ... -i inventory/mycluster/hosts.yaml
```

OR

keep the current hostnames

``` bash
echo "override_system_hostname: false" >>  inventory/mycluster/group_vars/all/all.yml
```

- Set Docker version to 19.03

The 18.09 version of Docker seems to be not available in apt sources, prefer the 19.03.

``` bash
echo "docker_version: 19.03"  >> inventory/mycluster/group_vars/all/docker.yml
```

- Set resolv.conf

There is more than one *resolv.conf* file on your Ubuntu 18+ O/S, use the right one!

A fix for Ubuntu 18.* has been [merged](https://github.com/kubernetes-sigs/kubespray/pull/3335) in Kubespray, but it does not apply on the not supported 19.* versions.

``` bash
echo 'kube_resolv_conf: "/run/systemd/resolve/resolv.conf"' >> inventory/mycluster/group_vars/all/all.yml
```

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

[[Top]](#table-of-contents)

### Deploy your cluster!

If you do not have turned on IPv4 and turned off swap manually, you can use:

``` bash
curl -LJO https://raw.githubusercontent.com/adriendelsalle/jhub-on-kubespray/master/kubespray/prepare-cluster.yaml
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root prepare-cluster.yaml
```

It's time to deploy Kubernetes by running the Ansible playbook command.

``` bash
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml
```

[[Top]](#table-of-contents)

### Access your cluster API

The cluster is created but you currently have no access to its API for configuration purpose.

`kubectl` has been installed by Kubespray on master nodes of your cluster and configuration files saved in root home directory.

If you want to access the cluster API from another computer on your network, install `kubectl` first.

``` bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```

In all cases, start by copying configuration files from root home directory to your user account used to deploy kubernetes.

Remember, it owns your SSH public key!

``` bash
ssh <node-user>@<master-node-ip> "sudo cp -R /root/.kube ~ && sudo chown -R <node-user>:<node-user> ~/.kube" 
```

If you plan to handle the API from another computer, download those files and update ownership.

``` bash
scp -r <node-user>@<master-node-ip>:~/.kube ~
sudo chown -R <local-user>:<local-user> ~/.kube
ssh <node-user>@<master-node-ip> "rm -r ~/.kube"
```

> Remove the configuration files from master node user to keep secrets protected

For sanity, use autocompletion!

``` bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
```

[[Top]](#table-of-contents)

---
## Still missing in your cluster

### Set a `LoadBalancer`

JupyterHub will expose a `Service` exposed with the `LoadBalancer` type. On a bare metal cluster, you don't have a load balancer since it's usually part of your cloud provider infrastructure.

For more details, refer to the official [documentation](https://kubernetes.io/docs/concepts/services-networking/service/).

Fortunately, [MetalLB](https://github.com/metallb/metallb) is a open-source implementation of a load balancer for bare metal deployments!

- Install MetalLB

Follow the official [installation guide](https://metallb.universe.tf/installation/).

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

To allow the load balancer to distribute external IPs, you must specify in its [configuration](https://metallb.universe.tf/configuration/#layer-2-configuration) what is the IP chunk allocated for it.

``` bash
cat << EOF | kubectl apply -f -
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
EOF
```

> Don't forget to set *your-ip-range* to the ip chunk you want to use! 

That's it!

[[Top]](#table-of-contents)

### Set a `StorageClass` and a provisioner

Deployments usually require storage in order to persist data since pods are designed to be ephemerals.

Kubernetes introduced several concepts around this:
- Persistant Volume `PV`: a declaration of an available volume
- Persistant Volume Claim `PVC`: a claim for Persistent Volume
- etc.

For more detailed information, please refer to the official Kubernetes documentation about [storage](https://kubernetes.io/docs/concepts/storage) that covers volumes/PV/PVC/provisioning/etc.

In this tutorial, you will use a `nfs` volume type for its simplicity, accessiblity between nodes and capability to be dynamically provisioned.

[[Top]](#table-of-contents)

#### Set up the NFS server

Based on the [Vitux tutorial](https://vitux.com/install-nfs-server-and-client-on-ubuntu/?__cf_chl_jschl_tk__=50c8eadb5fa04314c2916407c2751f68687aeb48-1587555276-0-AWkNR6Qizn6tsLLBsSUH1l_YOBi7OZLqRBXQzexN7S5FrW4QxNdSiOTwuRQaub2rjdraGI6zFVbGeKntmz-ZQW76uKjX4COBy5N14m8WXi0BRXvUlWDMxEvmlKs8iUrosn1-ctl7DoZlWbMWGIOFkGljgabLZv3CHBb0e-RpDRcUmuqFnv6Ct9PLcS2VGadHYKIuK5z9nKzU3qKACh3wHROeVhVH1Ibsel8NhqGCdPCWYBJn4EwR9WkUjFvf1Rycgv9751PotGabEq2l-_jipEoKgeo29yIk-uaWemKOPBiNvxjKhlZwNigfLGMAm4Mmuv6qWuGEKqQNKfLDjQjSRWwoSOqrRMbnXFs92AQCMt5knujCrI6RCDW699xX_fhnSmVjLDq_ra-BT3nVTRJV1D8).

  - Install NFS server

Just pick a machine on the same network as your cluster nodes (it can be one of them), and run:

``` bash
sudo apt-get install -y nfs-kernel-server
```
  - Choose export directory
  
Choose or create a directory and share it:

``` bash
sudo mkdir -p /mnt/my-nfs
```

As we want all clients to have access, change its permissions

``` bash
sudo chown nobody:nogroup /mnt/my-nfs
sudo chmod 777 /mnt/my-nfs
```

  - Do the NFS export

``` bash
echo "/mnt/my-nfs <subnetIP/24>(rw,sync,no_subtree_check)" | sudo tee /etc/exports
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

> You have to replace `subnetIP/24` by a correct CIDR.

[[Top]](#table-of-contents)

#### Define the `StorageClass` and the provisioner

Based on the [Yolanda tutorial](http://teknoarticles.blogspot.com/2018/10/setup-nfs-client-provisioner-in.html)

We will use [external-storage](https://github.com/kubernetes-incubator/external-storage] template.

- Set authorizations

``` bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs-client/deploy/rbac.yaml
```

- Set `StorageClass`

``` bash
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
  annotations: 
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: nfs-provisioner
parameters:
  archiveOnDelete: "false"
EOF
```

We declare the `StorageClass` as default one to automatically be selected by PVCs.

- Set provisioner

``` bash
cat << EOF | kubectl apply -f -
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
EOF
```

> Don't forget to set *nfs-server-ip* to your nfs server ip! 
   
  - Check everything is OK
  
``` bash
kubectl get deployments.apps,pods,sc -n default
```

You should see the deployment of the `Provisioner`, the corresponding `Pod` and also the `StorageClass` as default one.

[[Top]](#table-of-contents)

---
## Install JupyterHub

### Install Helm

Just run:

``` bash
sudo snap install helm --classic
```

[[Top]](#table-of-contents)

### Deploy JupyterHub from Helm chart

You can now follow the [zero-to-jupyterhub tutorial](https://zero-to-jupyterhub.readthedocs.io/en/latest/setup-jupyterhub/setup-jupyterhub.html)

- Add Helm repo

``` bash
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
```

- Create your configuration file

``` bash
cat << EOF > jhub-config.yaml
proxy:
  secretToken: "<RANDOM_HEX>"
EOF
sed -i "s/<RANDOM_HEX>/$(openssl rand -hex 32)/g" jhub-config.yaml
```


If you don't implement the [`StorageClass` and provisioner](#set-a-storageclass-and-a-provisioner) part of this tutorial, you have to modify your configuration file to store information *in-memory*. In that case you will lose all your data in case of cluster reboot, etc.

From JHub doc:
> Use an in-memory sqlite database. This should only be used for testing, since the database is erased whenever the hub pod restarts - causing the hub to lose all memory of users who had logged in before.

> When using this for testing, make sure you delete all other objects that the hub has created (such as user pods, user PVCs, etc) every time the hub restarts. Otherwise you might run into errors about duplicate resources.

``` bash
cat << EOF >> config.yaml

hub:
  db:
    type: sqlite-memory

singleuser:
  storage:
    type: sqlite-memory
EOF
```

- Deploy JupyterHub

``` bash
RELEASE=jhub
NAMESPACE=jhub

kubectl create namespace $NAMESPACE
helm upgrade --install $RELEASE jupyterhub/jupyterhub \
  --namespace $NAMESPACE  \
  --version=0.9.0 \
  --values config.yaml
```

> Don't forget that the Helm chart version differ from JupyterHub version! See the [jupyterhub/helm-chart repo](https://github.com/jupyterhub/helm-chart).

Here we are, I hope this tutorial was helpful!
Do not hesitate to make PR and have a great moment on JHub.

[[Top]](#table-of-contents)
