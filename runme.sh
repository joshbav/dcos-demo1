#!/bin/bash

### todo incorporate ssh tunnel from https://docs.mesosphere.com/services/kubernetes/1.0.1-1.9.4/connecting-clients/

# change example group to an actual dependency, scale app scales dbase, but rename it
#and everything from https://gist.github.com/ToddGreenstein/346b769c1ba552dad5371f2c8c908170
# use dcos cluster remove [<name> | --all] instead
# add keith's is_running() https://mail.google.com/mail/u/0/#inbox/162648922301ad6f
# and add example k8s app
# add alex's k8s demo
# and add /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --kiosk www.yahoo.com for k8s dashboard    https://<cluster-ip>/service/kubernetes-proxy/

# setup edge-lb newer verson, use service account, restrict access: https://docs.mesosphere.com/services/edge-lb/1.0/installing/

# add push job into jenkins https://wiki.jenkins.io/display/JENKINS/Remote+access+API

# combine simple-app-demo.json with this demo


# add from https://docs.google.com/document/d/1BYJHOEww_TcrfOqpZLcQjkNbSJGB6vMz-1Z2EEn9if4/edit#heading=h.g9m04fz12r7t

# add from https://docs.google.com/document/d/1Us-T8-by2DLxKQzA72XroKerfn5kAfuysyRBY4vCFf4/edit

# add cassandra from https://docs.google.com/document/d/1Gm9fq5XjWvjaGbgse6KL_m-FKlWwh2RD1xQnM5U65vg/edit

#
# Revision 8-21-18
#
# This script sets up an existing CCM cluster with nginx, older kubernetes, older cassandra, and basic load generators. 
#
# The first argument is the master URL, the second is the AWS ELB that is in front of the public agent
# Simply copy the URLs from CCM and paste them to the CLI
#

### SETUP BASH ALIASES INCASE I USE THEM, but on a mac only the 1st will be usefl
alias k='kubectl' j='journalctl' s='systemctl'

#### SETUP MASTER URL AND ELB URL
if [ $1 == "" ]
then
	echo
	echo " A master node's URL was not entered. Aborting."
	echo
	exit 1
fi
if [ $2 == "" ]
then
        echo
        echo " The ELB URL was not entered. Aborting."
        echo
        exit 1
fi
# For the master change http to https so kubectl setup doesn't break
MASTER_URL=$(echo $1 | sed 's/http/https/')
echo
echo "Master's URL: " $MASTER_URL
# For the public node's ELB change https to http, and change .com/ to just .com
ELB=$(echo $2 | sed s'/https/http/')
ELB=$(echo $ELB | sed s'/.com\//.com/')
echo
echo "Public agent ELB URL: " $ELB
echo
echo "This script will: install nginx, edge-lb for nginx, older kubernetes, and an older version of Cassandra."
echo "It will also wipe out your dcos cli and kubectl configurations."
echo "It will ssh-add the CCM private key, but it's assuming that key is ~/ccm-priv.key."
echo "An 11 node CCM cluster is necessary for this"
echo
read -p "Press enter to continue."
####


# Print each command as it's executed, for debugging
set -x
# Stop if any error happens
# set -e


#### CLEAN OU ALL EXISTING CLUSTERS SINCE WE USE A LOT OF CCM
# Warning, you might not want to delete all your CLI cluster configs
echo
echo "**** Removing all of the CLI's configured DC/OS clusters (rm -rf ~/.dcos/clusters)"
rm -rf ~/.dcos/clusters
# TODO consider dcos cluster remove --all   instead
echo
echo "**** Removing kubectl configuration (rm -rf ~/.kube)"
rm -rf ~/.kube
echo 
# Turn off cert verification since a self signed cert is used
echo "**** Running command: dcos cluster setup ..."
dcos cluster setup $MASTER_URL --insecure --username=bootstrapuser --password=deleteme
dcos config set core.ssl_verify false
####

#### ADD THE CCM SSH KEY, SINCE SSH-ADD IS EPHEMERAL AND A REBOOT WILL CLEAR IT
echo
echo "**** Adding CCM SSH key" 
ssh-add ~/ccm-priv.key
####

#### INSTALL KUBERNETES, this takes a while so starting it now
echo
echo "**** Installing older Kubernetes 1.10.5 with defaults"
dcos package install kubernetes --package-version=1.2.0-1.10.5 --yes 
## --options=kubernetes-config.json --yes
# In case K8s was deployed manually via the GUI before running this script
dcos package install kubernetes --package-version=1.2.0-1.10.5 --cli --yes
####

#### COMMENTED OUT - INSTALL KUBECTL
## per: https://kubernetes.io/docs/tasks/tools/install-kubectl/
## REMOVE ALL PREVIOUS VERSIONS
## brew uninstall --force kubernetes-cli
# rm /usr/local/bin/Kubectl
## per: https://kubernetes.io/docs/tasks/tools/install-kubectl/
## xcode-select --install
## https://github.com/golang/go/issues/19734  talks about the go version, 
## but I thought go doesn't need a runtime and it creates a statically linked .exe, but I installed go anyhow, 
# brew install go
## if it's already installed: brew upgrade kubernetes-cli
# brew install kubernetes-cli
# brew link kubernetes-cli
# brew install bash-completion
####

#### UPDATE DC/OS LICENSE TO 100 NODE SE LICENSE
# Since the CCM license is only 10 nodes
dcos license renew dcos-license.txt
####

#### INSTALL CLI SUBCOMMANDS
# Note the subcommand modules in 1.10 onward are now installed for a particular cluster, 
# thus the modules need to be re-installed for each new cluster
# So to make things simple we're just installing the common ones 
# The goal is to be able to do just a dcos command and have an impressive list for the demo
echo
echo "**** Installing DCOS CLI modules"
dcos package install dcos-enterprise-cli --cli --yes
dcos package install datastax-dse --cli --yes
dcos package install datastax-ops --cli --yes
dcos package install spark --cli --yes
dcos package install kafka --cli --yes
dcos package install confluent-kafka --cli --yes
dcos package install elastic --cli --yes
dcos package install hdfs --cli --yes
dcos package install kibana --cli --yes
dcos package install portworx --cli --yes
####
# debug # read -p "Press enter to continue."

#### EDGE-LB
echo
echo
echo "**** Installing repo for Edge-LB v1.0.3"
echo "NOTE: THIS MAY NOT BE THE NEWEST EDGE-LB VERSION!"
echo
dcos package repo add --index=0 edge-lb https://downloads.mesosphere.com/edgelb/v1.0.3/assets/stub-universe-edgelb.json 
dcos package install edgelb --yes
# For some reason the CLI sometimes does not install via the last command, thus:
dcos package install edgelb --cli --yes
dcos package repo add --index=0 edge-lbpool https://downloads.mesosphere.com/edgelb-pool/v1.0.3/assets/stub-universe-edgelb-pool.json
echo
echo "**** Installing edgelb-pool cli, which takes a while, probalby waiting for edge-lb to finish installing"
# For some reason the CLI sometimes does not install via the last command, thus:
dcos package install edgelb-pool --cli --yes
# Wait for Edge-LB to install
echo
echo "**** Waiting for edge-lb to install"
until dcos edgelb ping; do sleep 3 & echo "still waiting..."; done
####

#### INSTALL NGINX-EXAMPLE'S EDGE-LB CONFIG
if [ -e /tmp/nginx-example-edge-lb.yaml ]
then 
  rm /tmp/nginx-example-edge-lb.yaml rm 2>/dev/null
fi
# Take the ELB and strip off the http://
BACKEND=$(echo $ELB | sed 's/http:\/\///')  
sed "s|ReplaceThis|$BACKEND|g" nginx-example-edge-lb.yaml > /tmp/nginx-example-edge-lb.yaml
#echo
#read -p "Press enter to continue."
echo
echo "**** Creating NGINX config in edge-lb"
dcos edgelb create /tmp/nginx-example-edge-lb.yaml
####

#### INSTALL EDGELB KUBECTL PROXY CONFIG EVEN THOUGH I'M NOT USING IT AT THIS TIME
echo
echo "**** Installing kubectl proxy edge-lb config"
dcos edgelb create kubectl-proxy.yaml
####

#### INSTALL MARATHON JSONS
echo
echo "**** Installing marathon jsons"
dcos marathon app add nginx-example.json
dcos marathon app add nginx-load.json
dcos marathon app add allocation-load.json
# add example Marathon app group
dcos marathon group add example-dependency.json
####

#### INSTALL OLDER V2.2.0 OF CASSANDRA
# so we can later upgrade it to a newer version in the demo. 
echo
echo "**** Installing older cassandra"
dcos package install cassandra --package-version 2.2.0-3.0.16 --yes
# In case it was installed manually before running this script,
# which I do sometimes since I often terminate a node in AWS to show 
# cassandra repairing, we will now install the CLI
dcos package install cassandra --package-version 2.2.0-3.0.16 --cli --yes
####

#### SETUP TEAM1 USER AND GROUP
echo
echo "**** Setting up example DC/OS users, groups, folders, and secrets"
dcos security org users create user1 --password=deleteme
dcos security org groups create team1
dcos security org groups add_user team1 user1
dcos security secrets create /team1/secret --value="team1-secret"
dcos security org groups grant team1 dcos:secrets:list:default:/team1 full 
dcos security org groups grant team1 dcos:secrets:default:/team1/* full
dcos security org groups grant team1 dcos:service:marathon:marathon:services:/team1 full
dcos security org groups grant team1 dcos:adminrouter:service:marathon full
# Appears to be necessary per COPS-2534
dcos security org groups grant team1 dcos:secrets:list:default:/ read
# Make the marathon folder by making the app
dcos marathon app add team1-example.json
####

#### SETUP TEAM2 USER AND GROUP
dcos security org users create user2 --password=deleteme
dcos security org groups create team2
dcos security org groups add_user team2 user2
dcos security secrets create /team2/secret --value="team2-secret"
dcos security org groups grant team2 dcos:secrets:list:default:/team2 full 
dcos security org groups grant team2 dcos:secrets:default:/team2/* full
dcos security org groups grant team2 dcos:service:marathon:marathon:services:/team2 full
dcos security org groups grant team2 dcos:adminrouter:service:marathon full
# Appears to be necessary per COPS-2534
dcos security org groups grant team2 dcos:secrets:list:default:/ read
# Make the marathon folder by making the app
dcos marathon app add team2-example.json
####

#### ADD BINARY SECRET
echo
echo "Adding example binary secret, named binary-secret."
echo "To display it: dcos security secrets get /binary-secret"
dcos security secrets create /binary-secret --file binary-secret.txt
####

#### COMMENTED OUT - SETUP KUBECTL. RUNNING THIS AT THE END SINCE KUBERNETES WILL HAVE HOPEFULLY PARTIALLY INSTALLED BY NOW
#echo
#echo "**** Configuring kubectl"
#dcos kubernetes kubeconfig  --apiserver-url $ELB:6443 --insecure-skip-tls-verify
#sleep 1
####

#### COMMENTED OUT - ADD EXAMPLE K8S APP
#echo
#echo "**** Adding example kubernets app"
#kubectl apply -f k8s-example-app.yaml
####

echo
echo "**** DONE. NOTE: You must wait at least 20 seconds before nginx will appear behind the ELB"
