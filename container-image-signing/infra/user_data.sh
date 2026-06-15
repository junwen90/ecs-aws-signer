#!/bin/bash
# ECS Cluster Initialization Script

echo "Starting ECS agent initialization..."

# Update yum
yum update -y

# Configure ECS cluster name
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

# Start ECS agent
systemctl start ecs

# Enable ECS agent on boot
systemctl enable ecs

echo "ECS initialization completed"
