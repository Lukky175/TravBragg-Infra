#!/bin/bash

exec > /var/log/user-data-debug.log 2>&1
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "===== Jenkins Slave Bootstrap ====="

# Wait for internet
until ping -c 1 google.com > /dev/null 2>&1; do
  sleep 5
done

echo "Internet is UP"

# Install dependencies
apt update -y
apt install -y openjdk-17-jdk curl

update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java

# Create jenkins user safely
id -u jenkins &>/dev/null || useradd -m -s /bin/bash jenkins

# Setup directory
mkdir -p /home/jenkins
chown -R jenkins:jenkins /home/jenkins

MASTER_URL="http://${master_ip}:8080"

# Wait for Jenkins master
until curl -s $MASTER_URL/crumbIssuer/api/json > /dev/null 2>&1; do
  echo "Waiting for Jenkins master..."
  sleep 5
done

echo "Master is reachable"

cd /home/jenkins

# Download agent.jar with retry
until curl -f -O $MASTER_URL/jnlpJars/agent.jar; do
  echo "Retrying agent.jar download..."
  sleep 5
done

# Fetch secret with retry
until SECRET=$(curl -s -u admin:admin123 \
  $MASTER_URL/computer/slave-node/jenkins-agent.jnlp \
  | grep -oP '(?<=<argument>)[^<]+' | head -n 1); do
  echo "Waiting for agent secret..."
  sleep 5
done

echo "SECRET fetched"

# Fix ownership again (important)
chown -R jenkins:jenkins /home/jenkins

echo "Starting agent..."

# Run agent
sudo -u jenkins nohup java -jar /home/jenkins/agent.jar \
  -url $MASTER_URL \
  -name slave-node \
  -secret $SECRET \
  -workDir "/home/jenkins" \
  -webSocket > /home/jenkins/agent.log 2>&1 &

echo "===== Slave Connected ====="