#!/bin/sh -e

sudo rm -r /etc/petrus_agent
sudo rm -r /var/apps/petrus_agent
sudo systemctl stop petrus-agent
sudo systemctl disable petrus-agent
sudo rm /etc/systemd/system/petrus-agent.service
sudo systemctl daemon-reload

echo "petrus_agent uninstalled successfully"
