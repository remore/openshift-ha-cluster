
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
# oc adm policy add-cluster-role-to-user cluster-admin admin
ssh master1.$GUID.internal && exit # dummy login and exit to make sure .kube folder is created
mkdir /root/.kube
scp master1.$GUID.internal:/home/ec2-user/.kube/config /root/.kube/config
```

## 2. Configure CI/CD pipeline using Jenkins
```
# 0. 事前準備
# ===
oc login -u admin -p admin
oc create -f jenkins-pv.yaml
ansible nfs -m file -a "path=/srv/nfs/jenkins state=directory mode=0777 owner=nfsnobody group=nfsnobody"
oc new-project my-cicd
oc new-app jenkins-persistent --param ENABLE_OAUTH=true
oc new-app openshift/ruby~https://github.com/remore/ruby-ex
# ここまででまず動作確認しておく
ssh master1.$GUID.internal curl -s 172.30.44.112:8080 | grep "<h1>"
# <h1>Hi! Welcome to your Ruby application on OpenShift</h1> のように出る

# 1. JenkinsのGitHub連携の設定
# ===
# ここのページでまずはCredential情報をJenkinsとGitHubそれぞれに設定する
https://jenkins-my-cicd.apps.754d.example.opentlc.com/credentials/
 -> Globa DomainでAdd Credential し、秘密鍵を登録しておく
https://github.com/settings/keys
 -> GitHub側では公開鍵を登録しておく

# 2. Jenkinsの新規ジョブ作成
# ===
# 前述でAdd Credentialした認証情報でGitHUb連携を行う。
# ※以下の -u <USER>:<TOKEN> の部分は下記ページでAPI Tokenを表示させることで取得したものを利用
https://jenkins-my-cicd.apps.754d.example.opentlc.com/user/admin-admin/configure

curl --insecure -XPOST 'https://jenkins-my-cicd.apps.754d.example.opentlc.com/createItem?name=yourJobName' -u admin-admin:ea882b713e72c6eb079e979540c4ceb9 --data-binary @jenkins-config.xml -H "Content-Type:text/xml"

# 3. CI/CDのためのwebhook設定
# ===
 githubのremore/ruby-exのsettingsページを訪れて、
# https://github.com/remore/ruby-ex/settings/hooks/26223471
# jenkins連携のwebhookの設定のうち"Payload URL"の欄をdefaultの
# `https://jenkins.openshift.io/github-webhook/`
# から
# `https://jenkins-my-cicd.apps.754d.example.opentlc.com/github-webhook/`
# に変更する

# 3. 設定したCI/CDの動作確認
# ===
# https://github.com/remore/ruby-ex のページを訪れて、例えばconfig.ruの<h1>タグ内の文字列を s/Hi!/Hi hello!/ のように変更し、そのままmasterブランチへ変更内容をpushする
# これにより jenkinsサーバにwebhookが通知され、その結果としてjenkins経由でOpenShiftのビルドが走り新しいdeploymentがdeployされる

ssh master1.$GUID.internal curl -s 172.30.44.112:8080 | grep "<h1>"
# <h1>Hi hello 2nd! Welcome to your Ruby application on OpenShift</h1> のように変更結果を確認しておく

# 番外編）jenkinsのwebhookの設定周りはこのブログを参考にした
# ===
# https://developer.aiming-inc.com/infra/jenkins-github-webhook-collaboration/

#  HPAの設定
oc create -f limit-range.yaml -n my-cicd
oc create -f hpa.yaml -n my-cicd
```

## 3. Setting Multitenancy
```
# Change a few configuration on master nodes
oc create -f project-template.yaml
ansible-playbook multitenancy.yaml
ansible masters -m shell -a"systemctl restart atomic-openshift-master-api atomic-openshift-master-controllers"

# Creating initial users for clients
USERNAME=amy CLIENT=alpha /bin/bash create-user.sh
USERNAME=andrew CLIENT=alpha /bin/bash create-user.sh
USERNAME=brian CLIENT=beta /bin/bash create-user.sh
USERNAME=betty CLIENT=beta /bin/bash create-user.sh
```

## 3-ex. On-boarding new client documentation
TBD