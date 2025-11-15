#!/bin/bash
# Ingest and digest Slurm data into XDMoD
# This script runs INSIDE the container with access to XDMoD commands

set -e

CSV_PATH=/ingest/slurm-jobs.csv
LOG_DIR=/ingest
LOG_PATH="${LOG_DIR}/ingest.log"
RESOURCE_NAME=${RESOURCE_NAME:-fox}

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

echo "==> $(date): Starting XDMoD ingestion" | tee -a "$LOG_PATH"

if [ ! -f "$CSV_PATH" ]; then
  echo "ERROR: No data file found at $CSV_PATH" | tee -a "$LOG_PATH"
  exit 1
fi

echo "==> Shredding Slurm data from $CSV_PATH (resource: $RESOURCE_NAME)" | tee -a "$LOG_PATH"
xdmod-shredder -r "$RESOURCE_NAME" -f slurm -i "$CSV_PATH" 2>&1 | tee -a "$LOG_PATH"

echo "==> Running XDMoD ingestor" | tee -a "$LOG_PATH"
xdmod-ingestor 2>&1 | tee -a "$LOG_PATH"

echo "==> $(date): Ingestion complete" | tee -a "$LOG_PATH"
