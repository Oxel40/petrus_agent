#!/bin/sh -e

FILE=./secrets
if [ ! -f "$FILE" ]; then
    echo "$FILE does not exist. Create this file and add the agent secret in the following format:"
	echo ""
	echo 'AGENT_SECRET="super secret key"'
	echo ""
	exit
fi

MIX_ENV=prod mix deps.get
MIX_ENV=prod mix release
sudo mkdir /etc/petrus_agent
sudo cp secrets /etc/petrus_agent/
sudo mkdir -p /var/apps/petrus_agent
sudo cp -r _build /var/apps/petrus_agent/
sudo cp petrus-agent.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable petrus-agent
sudo systemctl start petrus-agent

echo <<EOF
petrus_agent installed. To view logs use (add -f if you want, check journalctl manual):

sudo journalctl -u petrus-agent

EOF
