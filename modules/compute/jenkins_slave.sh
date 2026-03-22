#!/bin/bash
echo "USER DATA STARTED at $(date)" > /home/ubuntu/userdata_started.txt

# Redirect all output to log file for debugging
exec > /var/log/user-data-debug.log 2>&1
set -euxo pipefail