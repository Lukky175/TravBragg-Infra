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

# Get PRIVATE IP (ONLY ONCE)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Private IP: $PRIVATE_IP"

# Prepare Jenkins home
mkdir -p /var/jenkins_home/init.groovy.d
chown -R 1000:1000 /var/jenkins_home

# Create Groovy init script
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

instance.setCrumbIssuer(new DefaultCrumbIssuer(true))

// ✅ FORCE CORRECT URL
def location = instance.getDescriptor("jenkins.model.JenkinsLocationConfiguration")
location.setUrl("http://${PRIVATE_IP}:8080/")
location.save()

instance.save()
EOF

# Pull Jenkins image
docker pull jenkins/jenkins:lts

# Run Jenkins (NO port 50000)
docker run -d \
  --name jenkins-master \
  --restart=always \
  -p 8080:8080 \
  -v /var/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Wait for Jenkins API
echo "Waiting for Jenkins to stabilize..."

until curl -s http://localhost:8080/api/json | jq -e '.mode' > /dev/null; do
  echo "Still initializing..."
  sleep 5
done

echo "Core ready → waiting extra..."
# Wait until admin user actually works (init scripts done)
until curl -s -u admin:admin123 http://localhost:8080/api/json > /dev/null; do
  echo "Waiting for Jenkins init scripts..."
  sleep 5
done

sleep 10

# Wait for computer API
until curl -s http://localhost:8080/computer/api/json | grep -q '"_class"'; do
  echo "Jenkins not fully ready..."
  sleep 5
done

echo "Jenkins ready"
sleep 20

JENKINS_URL="http://localhost:8080"
USER="admin"
PASS="admin123"

# Wait for auth
until curl -s -u $USER:$PASS $JENKINS_URL/api/json > /dev/null; do
  echo "Waiting for auth..."
  sleep 5
done

# Get crumb
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
    "launcher":{
      "stapler-class":"hudson.slaves.JNLPLauncher"
    }
  }')

if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "302" ]; then
  echo "Agent created successfully"
else
  echo "Agent creation FAILED with status $RESPONSE"
  exit 1
fi

echo "===== Master Setup Complete ====="