#!/bin/bash

### todo incorporate ssh tunnel from https://docs.mesosphere.com/services/kubernetes/1.0.1-1.9.4/connecting-clients/

# change example group to an actual dependency, scale app scales dbase, but rename it
#and everything from https://gist.github.com/ToddGreenstein/346b769c1ba552dad5371f2c8c908170
# use dcos cluster remove [<name> | --all] instead
# add keith's is_running() https://mail.google.com/mail/u/0/#inbox/162648922301ad6f
# and add example k8s app
# add alex's k8s demo
# add edgelb 1.0.1
# and add /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --kiosk www.yahoo.com for k8s dashboard    https://<cluster-ip>/service/kubernetes-proxy/

# add push job into jenkins https://wiki.jenkins.io/display/JENKINS/Remote+access+API

# combine simple-app-demo.json with this demo

# add example group deployment

# add from https://docs.google.com/document/d/1BYJHOEww_TcrfOqpZLcQjkNbSJGB6vMz-1Z2EEn9if4/edit#heading=h.g9m04fz12r7t

# add from https://docs.google.com/document/d/1Us-T8-by2DLxKQzA72XroKerfn5kAfuysyRBY4vCFf4/edit

# add cassandra from https://docs.google.com/document/d/1Gm9fq5XjWvjaGbgse6KL_m-FKlWwh2RD1xQnM5U65vg/edit

#
# Revision 3-21-18
#
# This script sets up an existing CCM cluster with nginx, kubernetes, cassandra, and basic load generators. 
#
# The first argument is the master URL, the second is the AWS ELB that is in front of the public agent
# Simply copy the URLs from CCM and paste them to the CLI
#

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
# For the master change https to http
MASTER_URL=$(echo $1 | sed 's/https/http/')
echo
echo "Master's URL: " $MASTER_URL
# For the public node's ELB change https to http, and change .com/ to just .com
ELB=$(echo $2 | sed s'/https/http/')
ELB=$(echo $ELB | sed s'/.com\//.com/')
echo
echo "Public agent ELB URL: " $ELB
echo
echo "This script will: install nginx, edge-lb for nginx, kubernetes, and a slightly older version of Cassandra."
echo "It will also wipe out your dcos cli and kubectl configurations."
echo "It will ssh-add the CCM private key, but it's assuming that key is ~/ccm-priv.key."
echo "An 11 node CCM cluster is necessary for this"
echo
read -p "Press enter to continue."
####

#### CLEAN OU ALL EXISTING CLUSTERS SINCE WE USE A LOT OF CCM
# Warning, you might not want this done if you have a normal lab system you use
echo
echo "**** Removing all of the CLI's configured DC/OS clusters (rm -rf ~/.dcos/clusters)"
rm -rf ~/.dcos/clusters
# TODO consider dcos cluster remove --all   instead
echo
echo "**** Removing kubectl configuration (rm -rf ~/.kube)"
rm -rf ~/.kube
echo 
echo "**** Running command: dcos cluster setup ..."
dcos cluster setup $MASTER_URL --insecure --username=bootstrapuser --password=deleteme
####

#### ADD THE CCM SSH KEY, SINCE SSH-ADD IS EPHEMERAL AND A REBOOT WILL CLEAR IT
ssh-add ~/ccm-priv.key
####

#### INSTALL KUBERNETES, this takes a while so starting it now
# The config file deploys it in HA mode, but we aren't using it
# because we can show an upgrade to HA while it's running.
echo
echo "**** Installing latest Kubernetes"
dcos package install kubernetes --yes
####

#### INSTALL AND SETUP KUBECTL
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

#### Install the CLI sub commands that might be used
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
echo "**** Installing repo for Edge-LB v1.0"
echo "NOTE: THIS MAY NOT BE THE NEWEST VERSION! THIS SCRIPT MAY NOTE BE UP TO DATE"
echo
dcos package repo add --index=0 edge-lb https://downloads.mesosphere.com/edgelb/v1.0.0/assets/stub-universe-edgelb.json 
dcos package install edgelb --yes
dcos package repo add --index=0 edge-lbpool https://downloads.mesosphere.com/edgelb-pool/v1.0.0/assets/stub-universe-edgelb-pool.json
echo
echo "**** Installing edgelb-pool cli, which takes a while, probalby waiting for edge-lb to finish installing"
dcos package install edgelb-pool --cli --yes
# Wait for Edge-LB to install
echo
echo "**** Waiting for edge-lb to install"
until dcos edgelb ping; do sleep 3 & echo "still waiting..."; done
####

#### INSTALL NGINX-EXAMPLE'S EDGE-LB CONFIG
rm /tmp/nginx-example-edge-lb.yaml 2>/dev/null
# Take the ELB and strip off the http://
BACKEND=$(echo $ELB | sed 's/http:\/\///')  
sed "s|ReplaceThis|$BACKEND|g" nginx-example-edge-lb.yaml > /tmp/nginx-example-edge-lb.yaml
#echo
#read -p "Press enter to continue."
echo
echo "**** Creating NGINX config in edge-lb"
dcos edgelb create /tmp/nginx-example-edge-lb.yaml
####

#### INSTALL MARATHON JSONS
echo
echo "**** Installing marathon jsons"
dcos marathon app add nginx-example.json
dcos marathon app add nginx-load.json
dcos marathon app add allocation-load.json
# add EXAMPLE DEPENDENCY AKA APP GROUP
dcos marathon group add example-dependency.json
####

#### Install older v2.0.3 of cassandra, so we can later upgrade it to a newer version in the demo. 
echo
echo "**** Installing older cassandra"
dcos package install cassandra --package-version 2.0.3-3.0.14 --yes
####

echo
echo "**** Setting up example DC/OS users, groups, folders, and secrets"
#### SETUP TEAM1 USER AND GROUP
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

#### Add binary secret
echo
echo "Adding example binary secret, named binary-secret."
echo "To display it: dcos security secrets get /binary-secret"
dcos security secrets create /binary-secret --file binary-secret.txt
####

#### SETUP KUBECTL. RUNNING THIS AT THE END SINCE KUBERNETES WILL HAVE HOPEFULLY PARTIALLY INSTALLED BY NOW
echo
echo "**** Configuring kubectl"
dcos kubernetes kubeconfig
sleep 1
####

#### ADD EXAMPLE K8S APP
echo
echo "**** Adding example kubernets app"
kubectl apply -f k8s-example-app.yaml
####

echo
echo "**** DONE. NOTE: You must wait at least 20 seconds before nginx will appear behind the ELB"
