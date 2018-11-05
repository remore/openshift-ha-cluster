
# scp -r /Users/ksawada/src/spike/openshift-ha-cluster ksawada-redhat.com@oselab-13a2.oslab.opentlc.com:/opt/work
cd /opt/work/openshift-ha-cluster/

# Initialize bastion
subscription-manager register --username=$RH_USERNAME --password=$RH_PASSWORD
yum install -y atomic-openshift-utils atomic-openshift-clients
export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc
cat hosts.template | sed "s/___GUID___/$GUID/g" | sed "s/___REGISTRY_USER___/$RH_USERNAME/g" | sed "s/___REGISTRY_PASSWORD___/$RH_PASSWORD/g" > /etc/ansible/hosts
ansible all -m shell -a 'export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc'

# Make sure all hosts are reachable
ansible all -m ping

# Make sure if docker is running on all nodes
ansible nodes -m shell -a"systemctl status docker"