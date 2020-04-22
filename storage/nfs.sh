#!/bin/bash

# Install NFS server
apt-get install -y nfs-kernel-server

# Choose export directory
mkdir -p /mnt/my-nfs
chown nobody:nogroup /mnt/my-nfs
chmod 777 /mnt/my-nfs

# Do the NFS export
echo "/mnt/my-nfs <subnetIP/24>(rw,sync,no_subtree_check)" >> /etc/exports
exportfs -a
systemctl restart nfs-kernel-server
