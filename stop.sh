#!/bin/bash

INSTANCE_NAME="xdmod"
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-rootpass123321}
DB_PORT=${DB_PORT:-9306}

if ! apptainer instance list | grep -q "^${INSTANCE_NAME}"; then
    echo "==> Instance '${INSTANCE_NAME}' is not running"
    exit 0
fi

echo "==> Gracefully shutting down services in instance '${INSTANCE_NAME}'..."

# Gracefully shutdown MariaDB
echo "==> Shutting down MariaDB..."
apptainer exec instance://${INSTANCE_NAME} \
    mysqladmin --port=${DB_PORT} -u root -p"${MYSQL_ROOT_PASS}" shutdown 2>/dev/null || \
    echo "    (MariaDB may already be stopped or not responding)"

# Give MariaDB a moment to shut down
sleep 2

# Gracefully stop Apache (it's running in foreground in the container, so SIGTERM will work)
echo "==> Stopping Apache and PHP-FPM..."
apptainer exec instance://${INSTANCE_NAME} pkill -TERM httpd 2>/dev/null || true
apptainer exec instance://${INSTANCE_NAME} pkill -TERM php-fpm 2>/dev/null || true

# Give services time to shut down gracefully
sleep 2

# Now stop the instance
echo "==> Stopping apptainer instance '${INSTANCE_NAME}'..."
apptainer instance stop ${INSTANCE_NAME}
echo "==> Instance stopped successfully"
