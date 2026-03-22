#!/bin/bash
echo "USER DATA STARTED at $(date)" > /home/ubuntu/userdata_started.txt

exec > /var/log/user-data-debug.log 2>&1
set -euxo pipefail

echo "===== Jenkins Master Bootstrap ====="

# Update system
apt update -y
apt install docker.io curl jq -y

systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Prepare Jenkins home BEFORE container starts
mkdir -p /var/jenkins_home/init.groovy.d
chown -R 1000:1000 /var/jenkins_home

# Create admin user (auto setup)
cat <<EOF > /var/jenkins_home/init.groovy.d/basic-security.groovy
#!groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin","admin123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)

instance.save()
EOF

# Pull Jenkins image
docker pull jenkins/jenkins:lts

# Run Jenkins
docker run -d \
  --name jenkins-master \
  -p 8080:8080 \
  -p 50000:50000 \
  -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
  -v /var/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

echo "Waiting for Jenkins..."
sleep 90   # IMPORTANT

JENKINS_URL="http://localhost:8080"
USER="admin"
PASS="admin123"

# Get crumb
CRUMB=$(curl -s -u $USER:$PASS "$JENKINS_URL/crumbIssuer/api/json")
CRUMB_FIELD=$(echo $CRUMB | jq -r .crumbRequestField)
CRUMB_VALUE=$(echo $CRUMB | jq -r .crumb)

# Create agent
curl -X POST "$JENKINS_URL/computer/doCreateItem?name=slave-node&type=hudson.slaves.DumbSlave" \
  -u $USER:$PASS \
  -H "$CRUMB_FIELD:$CRUMB_VALUE" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode 'json={
    "name":"slave-node",
    "nodeDescription":"Auto-created agent",
    "numExecutors":"1",
    "remoteFS":"/home/jenkins",
    "labelString":"linux",
    "mode":"NORMAL",
    "type":"hudson.slaves.DumbSlave",
    "retentionStrategy":{"stapler-class":"hudson.slaves.RetentionStrategy$Always"},
    "launcher":{"stapler-class":"hudson.slaves.JNLPLauncher"}
  }'

if [ $? -eq 0 ]; then
  echo "Agent created successfully"
else
  echo "Agent creation FAILED"
  exit 1
fi

echo "===== Master Setup Complete ====="