#!/bin/bash

# --- Configurable paths ---
HOST_XDMOD_CONFIG="./xdmod/etc"         # persistent host config
HOST_XDMOD_DATA="./xdmod/data"          # persistent XDMoD data
HOST_XDMOD_LOG="./xdmod/log"            # persistent log dir
HOST_MYSQL_DATA="./mariadb/lib"         # persistent MariaDB data
HOST_MYSQL_LOG="./mariadb/log"          # writable MariaDB log
HOST_MYSQL_RUN="./mariadb/run"          # writable MariaDB socket run dir
HOST_MYSQL_CONF="./mariadb/conf/my.cnf" # persistent MariaDB config

CONTAINER_IMAGE="xdmod-apptainer.sif"
TMP_BIND="/tmp/xdmod_defaults"

# --- Ensure host directories exist ---
mkdir -p "${HOST_XDMOD_CONFIG}" "${HOST_XDMOD_DATA}" "${HOST_XDMOD_LOG}" "${HOST_MYSQL_DATA}" "${HOST_MYSQL_LOG}" "${HOST_MYSQL_RUN}" "$(dirname $HOST_MYSQL_CONF)"
mkdir -p ./httpd/logs ./httpd/run ./httpd/ssl ./httpd/conf ./httpd/php-fpm ./httpd/php-fpm-run ./httpd/php-fpm-etc
mkdir -p ./ingest

# --- Step 1: Copy default configs if missing ---
if [ ! -f "${HOST_XDMOD_CONFIG}/portal_settings.ini" ]; then
  echo "==> Copying default XDMoD config from container to host..."
  apptainer exec \
    --bind "${HOST_XDMOD_CONFIG}:${TMP_BIND}" \
    "${CONTAINER_IMAGE}" \
    /bin/bash -c "cp -au /etc/xdmod/* ${TMP_BIND}/"
  chmod u+w "${HOST_XDMOD_CONFIG}"/*
fi

# --- Step 1.5: Create Apache and PHP-FPM config files if missing ---
if [ ! -f "./httpd/conf/xdmod.conf" ]; then
  echo "==> Creating default Apache XDMoD config..."
  cat >./httpd/conf/xdmod.conf <<'EOF'
# Default XDMoD Apache configuration
# This will be populated by XDMoD during setup
EOF
fi

if [ ! -f "./httpd/conf/mpm.conf" ]; then
  echo "==> Creating default Apache MPM config..."
  cat >./httpd/conf/mpm.conf <<'EOF'
# Default MPM prefork configuration
<IfModule mpm_prefork_module>
    StartServers             5
    MinSpareServers          5
    MaxSpareServers         10
    MaxRequestWorkers      250
    MaxConnectionsPerChild   0
</IfModule>
EOF
fi

if [ ! -f "./httpd/php-fpm-etc/www.conf" ]; then
  echo "==> Creating default PHP-FPM config..."
  cat >./httpd/php-fpm-etc/www.conf <<'EOF'
[www]
user = apache
group = apache
listen = /run/php-fpm/www.sock
listen.owner = apache
listen.group = apache
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
EOF
fi

# --- Step 2: Create MariaDB config if missing ---
if [ ! -f "${HOST_MYSQL_CONF}" ]; then
  echo "==> Creating MariaDB configuration file with XDMoD-recommended settings..."
  cat >"${HOST_MYSQL_CONF}" <<'EOF'
[mysqld]
# XDMoD recommended MariaDB configuration
sql_mode = ''
max_allowed_packet = 1G
group_concat_max_len = 16M
innodb_stats_on_metadata = off
innodb_file_per_table = On

# Performance tuning
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M

# Disable binary logging unless explicitly needed
skip-log-bin
log_bin_trust_function_creators = 1

# Networking
port = 9306
bind-address = 127.0.0.1

# General
character-set-server = utf8
collation-server = utf8_general_ci
EOF
fi

INSTANCE_NAME="xdmod"

# Check if this is a fresh installation
FRESH_INSTALL=false
if [ ! -d "${HOST_MYSQL_DATA}/mysql" ]; then
  FRESH_INSTALL=true
fi

# Check if instance is already running
if apptainer instance list | grep -q "^${INSTANCE_NAME}"; then
  echo "==> Instance '${INSTANCE_NAME}' is already running. Stopping it first..."
  apptainer instance stop ${INSTANCE_NAME}
  sleep 2
fi

echo "==> Starting apptainer instance '${INSTANCE_NAME}'..."
if apptainer instance start \
  --bind ${HOST_MYSQL_DATA}:/var/lib/mysql \
  --bind ${HOST_MYSQL_LOG}:/var/log/mariadb \
  --bind ${HOST_MYSQL_RUN}:/run/mariadb \
  --bind ${HOST_MYSQL_CONF}:/etc/my.cnf \
  --bind ${HOST_XDMOD_DATA}:/var/lib/xdmod \
  --bind ${HOST_XDMOD_CONFIG}:/etc/xdmod \
  --bind ${HOST_XDMOD_LOG}:/var/log/xdmod \
  --bind ./httpd/logs:/etc/httpd/logs \
  --bind ./httpd/run:/etc/httpd/run \
  --bind ./httpd/ssl:/etc/httpd/ssl \
  --bind ./httpd/conf/xdmod.conf:/etc/httpd/conf.d/xdmod.conf \
  --bind ./httpd/conf/mpm.conf:/etc/httpd/conf.d/mpm.conf \
  --bind ./httpd/php-fpm:/var/log/php-fpm \
  --bind ./httpd/php-fpm-run:/run/php-fpm \
  --bind ./httpd/php-fpm-etc/www.conf:/etc/php-fpm.d/www.conf \
  --bind ./xdmod-start.sh:/usr/local/bin/xdmod-start.sh \
  --bind ./ingest:/ingest \
  --bind ./scripts/ingest-digest.sh:/ingest-digest.sh \
  --bind $TMPDIR:$TMPDIR \
  --env DB_PORT=9306 \
  ${CONTAINER_IMAGE} \
  ${INSTANCE_NAME}; then
  echo ""
  echo "==> Instance started successfully!"
  echo "==> Instance name: ${INSTANCE_NAME}"

  if [ "$FRESH_INSTALL" = true ]; then
    echo ""
    echo "============================================================================"
    echo "  NOTICE: This appears to be a fresh installation!"
    echo ""
    echo "  You need to run xdmod-setup to configure XDMoD:"
    echo "    apptainer exec instance://xdmod xdmod-setup"
    echo ""
    echo "  After setup completes, restart the instance:"
    echo "    ./stop.sh && ./start.sh"
    echo "============================================================================"
  fi

  echo ""
  echo "==> Check status:  apptainer instance list"
  echo "==> View logs:     tail -f ./httpd/logs/error_log"
  echo "==> Stop instance: apptainer instance stop ${INSTANCE_NAME}"
else
  echo ""
  echo "==> ERROR: Failed to start instance '${INSTANCE_NAME}'"
  echo "==> Check the error messages above for details"
  exit 1
fi
