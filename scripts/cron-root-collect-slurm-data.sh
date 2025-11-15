#!/bin/bash
# Collect Slurm job data for XDMoD ingestion
# This script should run on the Slurm controller/head node with sacct access
# Typically scheduled via cron as root or slurm user

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGEST_DIR="${SCRIPT_DIR}/../ingest"
OUTFILE="${INGEST_DIR}/slurm-jobs.csv"

# Collect jobs from the last 5 days by default
DAYS_BACK=${DAYS_BACK:-1}
START_DATE=$(date -d "$DAYS_BACK day ago" +"%Y-%m-%d")
END_DATE=$(date +"%Y-%m-%d")

# Ensure output directory exists
mkdir -p "${INGEST_DIR}"

echo "==> Collecting Slurm job data from $START_DATE to $END_DATE"

sacct -S "$START_DATE" -E "$END_DATE" \
  --allusers --parsable2 --noheader --allocations --duplicates \
  --format jobid,jobidraw,cluster,partition,qos,account,group,gid,user,uid,submit,eligible,start,end,elapsed,exitcode,state,nnodes,ncpus,reqcpus,reqmem,reqtres,alloctres,timelimit,nodelist,jobname \
  >"$OUTFILE"

echo "==> Collected $(wc -l <"$OUTFILE") job records to $OUTFILE"
