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
apt install -y openjdk-17-jdk curl ca-certificates jq

# Create jenkins user safely
id -u jenkins &>/dev/null || useradd -m -s /bin/bash jenkins

# Setup directory
mkdir -p /home/jenkins
chown -R jenkins:jenkins /home/jenkins

MASTER_URL="http://${master_ip}:8080"

# ✅ Wait for Jenkins core
until curl -s $MASTER_URL/api/json > /dev/null; do
  echo "Waiting for Jenkins core..."
  sleep 5
done

echo "Jenkins core is UP"

# ✅ Wait for node creation
until curl -s -u admin:admin123 \
  $MASTER_URL/computer/slave-node/api/json | jq -e '.displayName=="slave-node"' > /dev/null; do
  echo "Waiting for Jenkins node creation..."
  sleep 5
done

echo "Node is ready"

cd /home/jenkins

# ✅ Download agent.jar
until curl -f -O $MASTER_URL/jnlpJars/agent.jar; do
  echo "Retrying agent.jar download..."
  sleep 5
done

# 🔥 WAIT FOR JNLP ENDPOINT (THIS FIXES HANDSHAKE)
until curl -s -u admin:admin123 \
  $MASTER_URL/computer/slave-node/jenkins-agent.jnlp | grep -q "<application-desc>"; do
  echo "Waiting for JNLP endpoint..."
  sleep 5
done

echo "JNLP endpoint ready"

# ✅ Fetch secret safely
while true; do
  SECRET=$(curl -s -u admin:admin123 \
    $MASTER_URL/computer/slave-node/ \
    | grep -oP '(?<=-secret )[a-f0-9]+' \
    | head -n 1)

  if [ -n "$SECRET" ]; then
    echo "SECRET fetched: $SECRET"
    break
  fi

  echo "Waiting for secret..."
  sleep 5
done

# Fix ownership
chown -R jenkins:jenkins /home/jenkins

echo "Starting agent..."

# ✅ Create agent script
cat <<EOF > /home/jenkins/start-agent.sh
#!/bin/bash
java -jar /home/jenkins/agent.jar \
  -jnlpUrl $MASTER_URL/computer/slave-node/jenkins-agent.jnlp \
  -secret $SECRET \
  -workDir "/home/jenkins"
EOF

chmod +x /home/jenkins/start-agent.sh
chown jenkins:jenkins /home/jenkins/start-agent.sh

# ✅ Start agent
sudo -u jenkins bash /home/jenkins/start-agent.sh > /home/jenkins/agent.log 2>&1 &

# ✅ Better wait for logs
sleep 10

echo "===== AGENT LOG ====="
cat /home/jenkins/agent.log || echo "No log found"

echo "===== Slave Connected ====="