#!/bin/bash
# Redis Cluster Initialization Script
# This script creates a Redis Cluster from 4 nodes (2 masters + 2 replicas)

set -e

echo "================================================"
echo "Redis Cluster Initialization Script"
echo "================================================"

# Configuration
NODES=(
  "redis-node-1:6379"
  "redis-node-2:6379"
  "redis-node-3:6379"
  "redis-node-4:6379"
)

# Wait for all nodes to be ready
echo ""
echo "Step 1: Waiting for all Redis nodes to be ready..."
for node in "${NODES[@]}"; do
  host="${node%%:*}"
  port="${node##*:}"

  echo "  Checking $host:$port..."
  until redis-cli -h "$host" -p "$port" ping > /dev/null 2>&1; do
    echo "    Waiting for $host:$port to be ready..."
    sleep 2
  done
  echo "    $host:$port is ready!"
done

echo ""
echo "All nodes are ready!"

# Check if cluster is already initialized
echo ""
echo "Step 2: Checking if cluster already exists..."
if redis-cli -h redis-node-1 -p 6379 cluster info | grep -q "cluster_state:ok"; then
  echo "  Cluster already initialized and healthy!"
  echo ""
  echo "Cluster Information:"
  redis-cli -h redis-node-1 -p 6379 cluster info
  echo ""
  echo "Cluster Nodes:"
  redis-cli -h redis-node-1 -p 6379 cluster nodes
  exit 0
fi

# Create the cluster
echo "  Cluster not found. Creating new cluster..."
echo ""
echo "Step 3: Creating Redis Cluster..."
echo "  - 2 Masters: redis-node-1, redis-node-2"
echo "  - 2 Replicas: redis-node-3 (replica of node-1), redis-node-4 (replica of node-2)"
echo ""

# The --cluster create command with --cluster-replicas 1 will:
# - Assign slots 0-8191 to redis-node-1
# - Assign slots 8192-16383 to redis-node-2
# - Make redis-node-3 a replica of redis-node-1
# - Make redis-node-4 a replica of redis-node-2
redis-cli --cluster create \
  redis-node-1:6379 \
  redis-node-2:6379 \
  redis-node-3:6379 \
  redis-node-4:6379 \
  --cluster-replicas 1 \
  --cluster-yes

echo ""
echo "================================================"
echo "Redis Cluster created successfully!"
echo "================================================"
echo ""
echo "Cluster Information:"
redis-cli -h redis-node-1 -p 6379 cluster info
echo ""
echo "Cluster Nodes:"
redis-cli -h redis-node-1 -p 6379 cluster nodes
echo ""
echo "================================================"
echo "You can now connect to the cluster via:"
echo "  - redis-cli -c -h redis-node-1 -p 6379"
echo "  - redis-cli -c -h redis-node-2 -p 6379"
echo "  - Or via cluster-proxy at cluster-proxy:6379"
echo "================================================"
