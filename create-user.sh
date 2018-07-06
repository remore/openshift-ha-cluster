echo "apiVersion: user.openshift.io/v1
groups: null
identities:
- htpasswd_auth:___USERNAME___
kind: User
metadata:
  name: ___USERNAME___
  labels:
    client: ___CLIENT___" | sed "s/___CLIENT___/$CLIENT/g" | sed "s/___USERNAME___/$USERNAME/g" | oc create -f -