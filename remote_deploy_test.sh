#!/bin/bash
set -ex
sudo rm -rf /tmp/deploy_ext && mkdir -p /tmp/deploy_ext
tar -xzf /home/ubuntu/deploy.tar.gz -C /tmp/deploy_ext
ls -R /tmp/deploy_ext
if [ -d "/tmp/deploy_ext/backend" ]; then
    sudo cp -rv /tmp/deploy_ext/backend/. /opt/debug-marathon/backend/
fi
if [ -d "/tmp/deploy_ext/frontend" ]; then
    sudo cp -rv /tmp/deploy_ext/frontend/. /opt/debug-marathon/frontend/
fi
sudo rm -rf /tmp/deploy_ext /home/ubuntu/deploy.tar.gz
sudo supervisorctl restart debug-marathon
