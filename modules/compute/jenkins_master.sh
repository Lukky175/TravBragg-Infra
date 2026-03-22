#!/bin/bash
echo "USER DATA STARTED at $(date)" > /home/ubuntu/userdata_started.txt

exec > /var/log/user-data-debug.log 2>&1
set -euxo pipefail

echo "===== Jenkins Master Bootstrap ====="

# Update system
apt update -y
apt install -y docker.io curl jq

systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Prepare Jenkins home
mkdir -p /var/jenkins_home/init.groovy.d
chown -R 1000:1000 /var/jenkins_home

# Create admin user + ENABLE CSRF
cat <<EOF > /var/jenkins_home/init.groovy.d/basic-security.groovy
#!groovy
import jenkins.model.*
import hudson.security.*
import hudson.security.csrf.DefaultCrumbIssuer

def instance = Jenkins.getInstance()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin","admin123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)

// ENABLE CSRF (IMPORTANT)
instance.setCrumbIssuer(new DefaultCrumbIssuer(true))

instance.save()
EOF

# Pull Jenkins
docker pull jenkins/jenkins:lts

# Run Jenkins

#AWS EC2 Metadata Service (IMDS) Every EC2 instance has a special internal endpoint
#169.254.169.254
#It returns instance information dynamically

MASTER_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

docker run -d \
  --name jenkins-master \
  -p 8080:8080 \
  -p 50000:50000 \
  -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Djenkins.model.JenkinsLocationConfiguration.url=http://${MASTER_IP}:8080/" \
  -v /var/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Wait until Jenkins is ready
echo "Waiting for Jenkins API to be ready..."

until curl -s http://localhost:8080/crumbIssuer/api/json | jq .crumb > /dev/null 2>&1; do
  echo "Jenkins still starting..."
  sleep 5
done

echo "Jenkins is FULLY READY"
echo "Jenkins is UP"

JENKINS_URL="http://localhost:8080"
USER="admin"
PASS="admin123"

# Get crumb + cookie
CRUMB_RESPONSE=$(curl -s -c cookies.txt -u $USER:$PASS \
  "$JENKINS_URL/crumbIssuer/api/json")

CRUMB_FIELD=$(echo $CRUMB_RESPONSE | jq -r .crumbRequestField)
CRUMB_VALUE=$(echo $CRUMB_RESPONSE | jq -r .crumb)

echo "Crumb fetched"

# Create agent
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -b cookies.txt \
  -u $USER:$PASS \
  -H "$CRUMB_FIELD:$CRUMB_VALUE" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST "$JENKINS_URL/computer/doCreateItem?name=slave-node&type=hudson.slaves.DumbSlave" \
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
  }')

if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "302" ]; then
  echo "Agent created successfully"
else
  echo "Agent creation FAILED with status $RESPONSE"
  exit 1
fi

echo "===== Master Setup Complete ====="