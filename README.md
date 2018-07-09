
## 0. Prerequisite
First of all, clone this repo to /opt/work folder at bastion host on your environment.
```
git clone https://github.com/remore/openshift-ha-cluster.git /opt/work/openshift-ha-cluster/
export RH_USERNAME=<YOUR_LOGIN_ID>
export RH_PASSWORD=<YOUR_LOGIN_PASSWORD>
```

## 1. Install Openshift v3.9 Cluster on your environment
Run following command on the bastion host as root user. This will give you OpenShift HA Cluster out of the box.
```
/bin/bash bootstrap.sh
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
```

Make sure that /root/.kube directory have valid credentials so that you can run oc command from bastion host.
```
source ~/.bashrc
ssh master1.$GUID.internal exit # dummy login and exit to make sure .kube folder is created
mkdir /root/.kube
scp master1.$GUID.internal:/home/ec2-user/.kube/config /root/.kube/config
```

## 2. Deploy Jenkins and sample application
Create `my-cicd` project and deploy 2 applications: `jenkins-persistent` and arbitrary application. Instead of `openshift-tasks`, this time I used `ruby-ex` app as an instance.
```
oc adm policy add-cluster-role-to-user cluster-admin admin
oc login -u admin -p admin
ansible nfs -m file -a "path=/srv/nfs/jenkins state=directory mode=0777 owner=nfsnobody group=nfsnobody"
cat jenkins-pv.yaml | sed "s/___GUID___/$GUID/g" | oc create -f -
oc new-project my-cicd
oc new-app jenkins-persistent --param ENABLE_OAUTH=true
oc new-app openshift/ruby~https://github.com/remore/ruby-ex
```

If the deployment was successful, you will see following command working:
```
export SERVICE_IP=`oc get service | grep ruby-ex | grep "[0-9]*\.[0-9]*\.[0-9]*.[0-9]*" -o`
ssh master1.$GUID.internal curl -s $SERVICE_IP:8080 | grep "<h1>"
# you will get something like: "<h1>Hi! Welcome to your Ruby application on OpenShift</h1>"
```

## 3. Configure CI/CD pipeline using Jenkins
Here are a few configurations you need to set for GitHub Integration. Take note that you need to replace $GUID with your real id in the following instructions:

- Setup credentials 
  * Visit Jenkins [setting page](https://jenkins-my-cicd.apps.$GUID.example.opentlc.com/credentials/store/system/) and add credentials with following values:
    * Kind: SSH username with private key
    * Scope: Global
    * Username: remore
    * Private Key: Enter directly
    * Passphrase: (blank)
    * ID: (blank)
    * Description: (blank)
  * Visit GitHub [setting page](https://github.com/settings/keys) and add corresponding public key
- Setup github hook setting
  * To make CI/CD work with GitHub, you need to have following webhook setting ready on your account:
    * setting page will be: https://github.com/remore/ruby-ex/settings/hooks/<your-hook-entry-id>
    * Payload URL: https://jenkins-my-cicd.apps.$GUID.example.opentlc.com/github-webhook/
    * Content Type: application/json
    * SSL verification: Disable
- Register new project via CLI using API Key
  * Visit following page and find your API Key
    * https://jenkins-my-cicd.apps.$GUID.example.opentlc.com/user/admin-admin/configure
  * Hit following command and get registered
```
export API_KEY=bcb3d137712c6b143d17c6b81fd4yyza
export CREDENTIAL_ID=ab29e21e-49bc-4274-b529-ce990d85xx22
cat jenkins-config.xml | sed "s/___CREDENTIAL_ID___/$CREDENTIAL_ID/g" | curl --insecure -XPOST "https://jenkins-my-cicd.apps.$GUID.example.opentlc.com/createItem?name=cicdTest" -u admin-admin:$API_KEY -d @- -H "Content-Type:text/xml"
```

If the curl command was successful, then you will see `cicdTest` project created on the list of projects at the Jenkins top page. This means your CI/CD pipeline is ready.

To test this, you can simply change any string(e.g. change "Hi!" to "Hola!") in the config.ru and push it. Hit the following command just like before, but this timee you will see the string "Hola".
```
export SERVICE_IP=`oc get service | grep ruby-ex | grep "[0-9]*\.[0-9]*\.[0-9]*.[0-9]*" -o`
ssh master1.$GUID.internal curl -s $SERVICE_IP:8080 | grep "<h1>"
# you will get something like: "<h1>Hola! Welcome to your Ruby application on OpenShift</h1>"
```

And lastly, execute following commands to set HPA.
```
oc create -f limit-range.yaml -n my-cicd
oc create -f hpa.yaml -n my-cicd
```

## 4. Setting Multitenancy
Change a few configurations on master nodes to:
- make new project template working
- add admissionControl setting
- set dedicated nodes for each clients

```
oc create -f project-template.yaml
ansible-playbook multitenancy.yaml
ansible masters -m shell -a"systemctl restart atomic-openshift-master-api atomic-openshift-master-controllers"

# Set node labels
oc label node node1.$GUID.internal client=alpha
oc label node node2.$GUID.internal client=beta
oc label node node3.$GUID.internal client=common

# Creating initial users for clients
USERNAME=amy CLIENT=alpha /bin/bash create-user.sh
USERNAME=andrew CLIENT=alpha /bin/bash create-user.sh
USERNAME=brian CLIENT=beta /bin/bash create-user.sh
USERNAME=betty CLIENT=beta /bin/bash create-user.sh
```

And as an On-boarding new client documentation: to create a new client/customer you need to execute following commands:
```
USERNAME=chris CLIENT=common /bin/bash create-user.sh
```