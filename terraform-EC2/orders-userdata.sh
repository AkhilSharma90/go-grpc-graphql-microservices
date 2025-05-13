#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

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
usermod -aG docker ubuntu || echo "Failed to add user to Docker group. Continuing as root."

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
echo "Building Docker image..."
docker build -f order/app.dockerfile -t orders . || { echo "Docker build failed!"; exit 1; }

# Run Docker container
echo "Running Docker container..."
docker run -d -p 80:8080 \
  -e DATABASE_URL_ORDER="postgres.orders.backend.in" \
  -e ACCOUNT_SERVICE_URL="backend.accounts.com:80" \
  -e ENV="prod" \
  -e CATALOG_SERVICE_URL="backend.catalog.com:80" \
  orders || { echo "Failed to start Docker container!"; exit 1; }

# Verify container is running
echo "Verifying Docker container..."
docker ps | grep orders && echo "Setup complete! You can access the application on port 80." || { echo "Container did not start successfully!"; exit 1; }
