#!/bin/bash -x

UBUNTU_RELEASE=$(lsb_release -r -s)

# install docker
apt update && apt install curl -y

curl https://packages.microsoft.com/config/ubuntu/${UBUNTU_RELEASE}/prod.list > /tmp/microsoft-prod.list
cp /tmp/microsoft-prod.list /etc/apt/sources.list.d/

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
cp /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/

apt update && apt install moby-engine moby-cli --allow-downgrades -y

# docker post-install
usermod -aG docker azureuser

curl -O https://raw.githubusercontent.com/jadarsie/AzureStack-QuickStart-Templates/devops-agent/101-devops-agent-on-docker/start.sh
curl -O https://raw.githubusercontent.com/jadarsie/AzureStack-QuickStart-Templates/devops-agent/101-devops-agent-on-docker/Dockerfile
docker build -t dockeragent:latest .

docker run -d \
--restart=always \
--name dockeragent \
-e AZP_URL=${AZP_URL} \
-e AZP_TOKEN=${AZP_TOKEN} \
-e AZP_AGENT_NAME=${AZP_AGENT_NAME} \
-e AZP_POOL=${AZP_POOL} \
dockeragent:latest