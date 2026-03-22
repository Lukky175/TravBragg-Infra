#!/bin/bash
echo "USER DATA STARTED at $(date)" > /home/ubuntu/userdata_started.txt

# Redirect all output to log file for debugging
exec > /var/log/user-data-debug.log 2>&1
set -euxo pipefail

echo "===== Jenkins Slave Bootstrap ====="

until ping -c 1 google.com; do
  echo "Waiting for internet..."
  sleep 5
done

apt update -y
apt install docker.io curl jq -y

systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

docker pull jenkins/inbound-agent

JENKINS_URL="http://${master_ip}:8080"
USER="admin"
PASS="admin123"

echo "Waiting for Jenkins..."
sleep 120   # IMPORTANT

# Get crumb
CRUMB=$(curl -s -u $USER:$PASS $JENKINS_URL/crumbIssuer/api/json | jq -r .crumb)

# Get agent secret
SECRET=$(curl -s -u $USER:$PASS \
  "$JENKINS_URL/computer/slave-node/jenkins-agent.jnlp" \
  | grep -oP '(?<=<argument>).*?(?=</argument>)' | head -n 1)

echo "Secret fetched"

# Run agent
docker run -d \
  --name jenkins-agent \
  -e JENKINS_URL=$JENKINS_URL \
  -e JENKINS_AGENT_NAME=slave-node \
  -e JENKINS_SECRET=$SECRET \
  jenkins/inbound-agent

echo "===== Slave Connected ====="