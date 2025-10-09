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
  "redis-node-5:6379"
  "redis-node-6:6379"
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
echo "  - 3 Masters: redis-node-1, redis-node-2, redis-node-3"
echo "  - 3 Replicas: redis-node-4, redis-node-5, redis-node-6"
echo ""

# The --cluster create command with --cluster-replicas 1 will:
# - First 3 nodes become masters (node-1, node-2, node-3)
# - Assign slots evenly across masters:
#   - redis-node-1: slots 0-5460
#   - redis-node-2: slots 5461-10922
#   - redis-node-3: slots 10923-16383
# - Remaining 3 nodes become replicas (node-4, node-5, node-6)
redis-cli --cluster create \
  redis-node-1:6379 \
  redis-node-2:6379 \
  redis-node-3:6379 \
  redis-node-4:6379 \
  redis-node-5:6379 \
  redis-node-6:6379 \
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
echo "  - Or via redis-cluster-proxy at redis-cluster-proxy:6379"
echo "================================================"
