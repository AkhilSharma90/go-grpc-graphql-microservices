#!/bin/bash

set -e  # Exit on any error

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
usermod -aG docker "$USER" || echo "Failed to add user to Docker group. You may need to run Docker with root privileges."

# Clean up unused packages
apt-get autoremove -y
apt-get clean

# Verify Docker installation
echo "Docker version:"
docker --version || { echo "Docker installation failed!"; exit 1; }

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
apt-get install -y postgresql-client-16 || { echo "Failed to install PostgreSQL client!"; exit 1; }

# Clone repository
REPO_URL="https://github.com/sujalsharmaa/go-grpc-graphql-microservices.git"
git clone -b features/cloud-and-devops-features "$REPO_URL" || { echo "Failed to clone repository!"; exit 1; }
cd go-grpc-graphql-microservices


docker build -f account/app.dockerfile -t accounts . || { echo "Docker build for accounts failed!"; exit 1; }

# Run Docker container for the accounts service
echo "Running Docker container for the accounts service..."
docker run -d -p 80:8080 \
  -e ENV="prod" \
  -e DATABASE_URL_ACCOUNT="postgres.accounts.backend.com" \
  accounts || { echo "Failed to start Docker container for accounts!"; exit 1; }

echo "Setup complete! The accounts service is running on port 8080."
