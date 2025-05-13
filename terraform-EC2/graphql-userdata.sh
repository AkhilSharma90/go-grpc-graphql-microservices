#!/bin/bash

# Exit on any error
set -e

# Update and install essential tools
echo "Updating system and installing prerequisites..."
apt-get update -y && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release unzip git

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
usermod -aG docker ubuntu || echo "Failed to add user to Docker group. Ensure you have root privileges."

# Clean up unused packages
apt-get autoremove -y
apt-get clean

# Verify Docker installation
echo "Docker version:"
docker --version || { echo "Docker installation failed!"; exit 1; }

# Clone repository
REPO_URL="https://github.com/sujalsharmaa/go-grpc-graphql-microservices.git"
git clone -b features/cloud-and-devops-features "$REPO_URL" || { echo "Failed to clone repository!"; exit 1; }
cd go-grpc-graphql-microservices

# Build Docker image
echo "Building Docker image for GraphQL service..."
docker build -f graphql/app.dockerfile -t graphql . || { echo "Docker build failed!"; exit 1; }

# Run Docker container
echo "Running Docker container for GraphQL service..."
docker run -d -p 80:8080 \
  -e CATALOG_SERVICE_URL="backend.catalog.com:80" \
  -e ACCOUNT_SERVICE_URL="backend.accounts.com:80" \
  -e ORDER_SERVICE_URL="backend.orders.com:80" \
  graphql || { echo "Failed to start Docker container!"; exit 1; }

echo "Setup complete! You can access the GraphQL application on port 80."
