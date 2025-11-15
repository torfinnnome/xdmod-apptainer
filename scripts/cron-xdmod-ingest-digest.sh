#!/bin/bash
# Wrapper script to run XDMoD ingestion inside the running container instance
# This should be scheduled via cron AFTER collecting Slurm data

set -e

INSTANCE_NAME="xdmod"
RESOURCE_NAME=${RESOURCE_NAME:-fox}

# Check if instance is running
if ! apptainer instance list | grep -q "^${INSTANCE_NAME}"; then
  echo "ERROR: XDMoD instance '${INSTANCE_NAME}' is not running"
  echo "Start it with: ./start.sh"
  exit 1
fi

echo "==> Running ingestion in container instance '${INSTANCE_NAME}'"

# Execute the ingestion script inside the running instance
apptainer exec instance://${INSTANCE_NAME} \
  bash -c "cd /tmp && RESOURCE_NAME=${RESOURCE_NAME} bash /ingest-digest.sh"

echo "==> Ingestion job submitted. Check logs at: ./ingest/ingest.log"
