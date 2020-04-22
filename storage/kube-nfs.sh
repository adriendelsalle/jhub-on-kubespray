#!/bin/bash

# Set authorizations
kubectl apply -f https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs-client/deploy/rbac.yaml

# Set StorageClass
kubectl apply -f nfs-storageclass.yaml

# Set Provisioner
kubectl apply -f nfs-provisioner.yaml
