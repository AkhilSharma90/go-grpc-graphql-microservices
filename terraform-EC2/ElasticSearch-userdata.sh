#!/bin/bash

# Update and install essential tools
echo "Updating system and installing prerequisites..."
apt-get update -y && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release unzip

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker

# Add user to Docker group
echo "Adding user to Docker group..."
usermod -aG docker ubuntu

# Clean up unused packages
apt-get autoremove -y
apt-get clean

# Verify Docker installation
echo "Docker version:"
docker --version || { echo "Docker installation failed!"; exit 1; }
docker run -d -p 80:9200 \
  --memory=2g \
  -e ES_JAVA_OPTS="-Xms1g -Xmx1g" \
  -e discovery.type="single-node" \
  docker.elastic.co/elasticsearch/elasticsearch:6.2.4
 || { echo "Failed to start Docker container!"; exit 1; }

echo "Setup complete! You can access the application on port 80."