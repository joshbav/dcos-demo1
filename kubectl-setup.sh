#!/bin/bash

# This is how to run kubectl on the newer k8s on dc/os without setting up the proxy. The idea is to run kubectl on a master and use a minuteman address.


# you must first: 
#dcos node ssh --master-proxy --leader
#then
#toolbox 
#(launch coreos's fedora container, since you can't install anything in coreos)

# curl -o /tmp/setupcli.sh -O  

#### GET DC/OS 1.11 CLI
echo
echo "Fetching DC/OS 1.11 CLI"
curl -o /usr/local/bin/dcos -O https://downloads.dcos.io/binaries/cli/linux/x86-64/dcos-1.11/dcos
chmod +x /usr/local/bin/dcos
####

#### SETUP DC/OS CLI
# NOTE: Must be running this script on DC/OS master
echo
echo "SETTING UP DC/OS CLI TO 127.0.0.1 AS MASTER"
dcos cluster setup https://127.0.0.1 --username=bootstrapuser --password=deleteme --insecure
####

#### SETUP KUBECTL REPO SO IT PULLS THE LATEST VERSION, INSTALL IT
echo
echo "SETTING UP KUBECTL YUM REPO"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
echo "INSTALLING KUBECTL"
yum install -y kubectl
####

#### INSTALL DC/OS CLI KUBERNETES CLIENT, LATEST VERSION
echo
echo "INSTALLING DC/OS KUBERNETES CLI MODULE, LATEST VERSION"
dcos package install kubernetes --cli --yes
####

#### SETUP KUBECTL
echo
echo "SETTING UP KUBECTL"
dcos kubernetes kubeconfig --apiserver-url=https://apiserver.kubernetes.l4lb.thisdcos.directory:6443 --insecure-skip-tls-verify
####

#### INSTALL EXAMPLE K8S APPS
## left off here

