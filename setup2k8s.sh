#### This script will install 2 K8s v2.0.0-1.12.1 clusters in 1.12, edge-lb, and configure edge-lb for kubectl
#### NOTE: This script will move your existing kubectl config file to /tmp/kubectl-config
#### by JoshB, following Alex Ly's setup directons at https://github.com/ably77/dcos-se/blob/master/Kubernetes/mke/README.md
#### Note some changes were made from Alex's config, for example the first k8s cluster was renamed to kubernetes-cluster1
#### Revision 11-13-18

#### USAGE
# 1. Create a 13 node or greater CCM cluster
# 2. Type ./setup2k8s.sh  (but don't press enter) 
# 3. In CCM right click on Dashboard (master), choose copy link address. Paste as first parameter. 
#    Don't worry about it being HTTP, the script will convert it to HTTPS

#### OTHER FILES
# 1. k8s-cluster1-options.json
# 2. k8s-cluster2-options.json
# 3. edge-lb-options.json
# 4. edgelb-kubectl-two-clusters.json 

#### WHAT THIS DOESN'T DO
# 1. Fix the DC/OS license
# 2. Install example apps into the cluster
# 3. Use the latest K8s. This way we can demo the upgrade process.
# 4. WHAT ELSE? TODO!


#### BEGINNING OF SCRIPT ####

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
echo "**** Running command: dcos cluster setup ..."
dcos cluster setup $MASTER_URL --insecure --username=bootstrapuser --password=deleteme

#### INSTALL ENTERPRISE CLI & SET CORE.SSL_VERIFY TO FALSE
echo
echo "**** Installing enterprise CLI"
dcos package install dcos-enterprise-cli --yes
echo
echo "**** Setting core.ssl_verify to false"
dcos config set core.ssl_verify false

#### MOVE KUBECONFIG FILE
echo
echo "**** If /tmp/kubectl-config file exists, deleting it"
rm -f /tmp/kubectl-config 2 > /dev/null
echo "**** If ~/.kube/config exists, moving it to /tmp/kubectl-config"
echo "     Therefore you now have no kubectl config file!"
if [[ -e ~/.kube/config ]]; then 
    mv ~/.kube/config /tmp/kube-config
fi

#### INSTALL MKE
echo
echo "**** Installing kubernetes manager (MKE) and Kubernetes CLI module"
dcos package install kubernetes --yes
# Might be redundant, but is harmless
dcos package install kubernetes --cli --yes

#### CREATE THE KUBERNETES-CLUSTER1 SERVICE ACCOUNT:
echo
echo "**** Creating service account for K8s cluster 1"
rm -f /tmp/cluster1-private-key.pem 2> /dev/null
rm -f /tmp/cluster1-public-key.pem 2> /dev/null
dcos security org service-accounts keypair /tmp/cluster1-private-key.pem /tmp/cluster1-public-key.pem
dcos security org service-accounts create -p /tmp/cluster1-public-key.pem -d 'Kubernetes cluster 1 service account' kubernetes-cluster1
dcos security secrets create-sa-secret /tmp/cluster1-private-key.pem kubernetes-cluster1 kubernetes-cluster1/sa

#### GRANT THE KUBERNETES-CLUSTER1 SERVICE ACCOUNT PERMISSIONS:
echo
echo "**** Setting up DC/OS permissions for K8s cluster 1"
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:task:user:root create
dcos security org users grant kubernetes-cluster1 dcos:mesos:agent:task:user:root create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:reservation:role:kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:reservation:principal:kubernetes-cluster1 delete
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:volume:role:kubernetes-cluster-role1 create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:volume:principal:kubernetes-cluster1 delete
dcos security org users grant kubernetes-cluster1 dcos:secrets:default:/kubernetes-cluster1/* full
dcos security org users grant kubernetes-cluster1 dcos:secrets:list:default:/kubernetes-cluster1 read
dcos security org users grant kubernetes-cluster1 dcos:adminrouter:ops:ca:rw full
dcos security org users grant kubernetes-cluster1 dcos:adminrouter:ops:ca:ro full
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:slave_public/kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:slave_public/kubernetes-cluster1-role read
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:reservation:role:slave_public/kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:volume:role:slave_public/kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:slave_public read
dcos security org users grant kubernetes-cluster1 dcos:mesos:agent:framework:role:slave_public read

#### INSTALL KUBERNETES CLUSTER #1:
# Usually MKE isn't done installing yet, so sleep for 15
sleep 15
echo
echo "**** Installing K8s cluster 1 v2.0.0-1.12.1 using k8s-cluster1-options.json"
dcos kubernetes cluster create --package-version=2.0.0-1.12.1 --options=k8s-cluster1-options.json --yes
# dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1

#### CREATE THE KUBERNETES-CLUSTER2 SERVICE ACCOUNT:
rm -f /tmp/cluster2-private-key.pem 2> /dev/null
rm -f /tmp/cluster2-public-key.pem 2> /dev/null
dcos security org service-accounts keypair /tmp/cluster2-private-key.pem /tmp/cluster2-public-key.pem
dcos security org service-accounts create -p /tmp/cluster2-public-key.pem -d 'Kubernetes cluster 2 service account' kubernetes-cluster2
dcos security secrets create-sa-secret /tmp/cluster2-private-key.pem kubernetes-cluster2 kubernetes-cluster2/sa

#### GRANT THE KUBERNETES-CLUSTER2 SERVICE ACCOUNT PERMISSIONS:
echo
echo "**** Setting up DC/OS permissions for K8s cluster 2"
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:framework:role:kubernetes-cluster2-role create
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:task:user:root create
dcos security org users grant kubernetes-cluster2 dcos:mesos:agent:task:user:root create
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:reservation:role:kubernetes-cluster2-role create
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:reservation:principal:kubernetes-cluster2 delete
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:volume:role:kubernetes-cluster2-role create
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:volume:principal:kubernetes-cluster2 delete
dcos security org users grant kubernetes-cluster2 dcos:secrets:default:/kubernetes-cluster2/* full
dcos security org users grant kubernetes-cluster2 dcos:secrets:list:default:/kubernetes-cluster2 read
dcos security org users grant kubernetes-cluster2 dcos:adminrouter:ops:ca:rw full
dcos security org users grant kubernetes-cluster2 dcos:adminrouter:ops:ca:ro full
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:framework:role:slave_public/kubernetes-cluster2-role create
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:framework:role:slave_public/kubernetes-cluster2-role read
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:reservation:role:slave_public/kubernetes-cluster2-role create
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:volume:role:slave_public/kubernetes-cluster2-role create
dcos security org users grant kubernetes-cluster2 dcos:mesos:master:framework:role:slave_public read
dcos security org users grant kubernetes-cluster2 dcos:mesos:agent:framework:role:slave_public read

#### INSTALL KUBERNETES CLUSTER #2:
# changed the json file to be just minimum needed for the change
echo
echo "**** Installing K8s cluster 2 v2.0.0-1.12.1 using k8s-cluster2-options.json"
dcos kubernetes cluster create --package-version=2.0.0-1.12.1 --options=k8s-cluster2-options.json --yes
# dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster2

#### INSTALL EDGE-LB V1.2.1
dcos package repo add --index=0 edge-lb https://downloads.mesosphere.com/edgelb/v1.2.1/assets/stub-universe-edgelb.json
dcos package repo add --index=0 edge-lbpool https://downloads.mesosphere.com/edgelb-pool/v1.2.1/assets/stub-universe-edgelb-pool.json

rm -f /tmp/edge-lb-private-key.pem 2> /dev/null
rm -f /tmp/edge-lb-public-key.pem 2> /dev/null
# CHANGE: commented out two lines
dcos security org service-accounts keypair /tmp/edge-lb-private-key.pem /tmp/edge-lb-public-key.pem
dcos security org service-accounts create -p /tmp/edge-lb-public-key.pem -d "Edge-LB service account" edge-lb-principal
# dcos security org service-accounts show edge-lb-principal
# Getting error on next line, says it already exists, assuming it was added for a strict mode cluster?
dcos security secrets create-sa-secret --strict /tmp/edge-lb-private-key.pem edge-lb-principal dcos-edgelb/edge-lb-secret
# Getting error on next line, says already part of group
dcos security org groups add_user superusers edge-lb-principal

dcos package install --options=edgelb-options.json edgelb --yes
# Is redundant but harmless
dcos package install edgelb --cli --yes
echo
echo "**** Waiting for edge-lb to install"
sleep 25
echo
echo "Ignore any 404 errors on next line that begin with  dcos-edgelb: error: Get https://"
until dcos edgelb ping; do sleep 3 & echo "still waiting..."; done

#### DEPLOY EDGELB CONFIG FOR KUBECTL
# CHANGE: different file name, modified definition to point to cluster1 instead of cluster
echo
echo "Deploying edgelb config from edgelb-kubectl-two-clusters.json"
dcos edgelb create edgelb-kubectl-two-clusters.json
sleep 30
echo
echo "Running dcos edgelb status edgelb-kubectl-two-clusters"
echo "If this command doensn't work the script will break"
dcos edgelb status edgelb-kubectl-two-clusters
echo
echo "Running dcos edgelb show edgelb-kubectl-two-clusters"
dcos edgelb show edgelb-kubectl-two-clusters

#### WAITING TO AVOID ERROR WITH DCOS KUBECONFIG
# For some reason even though the k8s clusters are done installing, there's still a delay needed to 
# run dcos kubernetes kubeconfig, otherwise this error will result:
#    Response: the service account secret has not been created yet
#    Response data (51 bytes): the service account secret has not been created yet
echo
echo "**** Sleeping for 60 to wait for K8s clusters to finish installing, before running dcos kubernetes kubeconfig, to avoid an error condition" 
sleep 60

#### GET PUBLIC IP OF EDGELB PUBLIC AGENT
# This is a real hack, and it might not work correctly! 
echo
echo "**** Setting env var EDGELB_PUBLIC_AGENT_IP using a hack of a method, beware"
export EDGELB_PUBLIC_AGENT_IP=$(dcos task exec -it edgelb-pool-0-server curl ifconfig.co | tr -d '\r' | tr -d '\n')
echo
echo Public IP of EdgeLB node is: $EDGELB_PUBLIC_AGENT_IP
# NOTE, if that approach to finding the public IP doesn't work, consider https://github.com/ably77/dcos-se/tree/master/Kubernetes/mke/public_ip

#### CONNECT KUBECTL TO KUBERNETES CLUSTER #1 AT PORT :6443
echo
echo "**** Connecting kubectl to cluster 1"
dcos kubernetes cluster kubeconfig --insecure-skip-tls-verify --context-name=kubernetes-cluster1 --cluster-name=kubernetes-cluster1 --apiserver-url=https://$EDGELB_PUBLIC_AGENT_IP:6443

echo
echo "Running kubectl get nodes for k8s cluster 1"
kubectl get nodes

#### CONNECT KUBECTL TO KUBERNETES CLUSTER #2 AT PORT :6444
echo
echo "**** Connecting kubectl to cluster 2"
dcos kubernetes cluster kubeconfig --insecure-skip-tls-verify --context-name=kubernetes-cluster2 --cluster-name=kubernetes-cluster2 --apiserver-url=https://$EDGELB_PUBLIC_AGENT_IP:6444

echo
echo "Running kubectl get nodes for k8s cluster 2"
kubectl get nodes

echo
echo "**** END OF SCRIPT"
