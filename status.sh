#!/bin/bash

INSTANCE_NAME="xdmod"

echo "==> Apptainer instances:"
apptainer instance list

echo ""
if apptainer instance list | grep -q "^${INSTANCE_NAME}"; then
    echo "==> Instance '${INSTANCE_NAME}' is RUNNING"
    echo ""
    echo "==> Recent Apache error log:"
    tail -20 ./httpd/logs/error_log 2>/dev/null || echo "  (no error log yet)"
    echo ""
    echo "==> Recent MariaDB log:"
    tail -20 ./mariadb/log/mariadb.log 2>/dev/null || echo "  (no MariaDB log yet)"
else
    echo "==> Instance '${INSTANCE_NAME}' is NOT running"
    echo "==> Run ./runme.sh to start it"
fi
