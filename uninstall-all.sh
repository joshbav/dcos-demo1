# This is to undo most (not all) the runme script, when it's used on a persistant cluster
# instead of ccm. This allows the agent nodes to be terminated without leaving any frameworks still installed

# TODO: remove what's created by runme's dcos security commands

dcos package uninstall edgelb --yes 
dcos package uninstall edgelb-pool --yes
dcos package uninstall kubernetes --yes
dcos marathon app remove kubernetes-proxy
dcos package uninstall cassandra --yes
dcos marathon app remove allocation-load
dcos marathon app remove /example-dependency/app/nginx
dcos marathon app remove /example-dependency/database/mysql
dcos marathon app remove nginx-example
dcos marathon app remove nginx-load
dcos marathon app remove /team1/simple-example
dcos marathon app remove /team2/simple-example 
