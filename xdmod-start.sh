#!/bin/bash
set -eu

DB_PORT=${DB_PORT:-9306}
MYSQL_DATA_DIR=/var/lib/mysql
MYSQL_LOG=/var/log/mariadb/mariadb.log
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-rootpass123321}
XDMOD_CONFIG_DIR=/etc/xdmod
XDMOD_DATA_DIR=/var/lib/xdmod
XDMOD_USER=${XDMOD_USER:-xdmod}
XDMOD_PASS=${XDMOD_PASS:-xdpass43}
XDMOD_DB=${XDMOD_DB:-xdmod}

export XDMOD_CONFIG_DIR=/var/lib/xdmod/config

# Create config dir if missing
mkdir -p ${XDMOD_CONFIG_DIR} ${XDMOD_DATA_DIR} ${MYSQL_DATA_DIR}

# --- Step 2: Initialize MariaDB if empty ---
if [ ! -d "${MYSQL_DATA_DIR}/mysql" ]; then
  echo "==> Initializing MariaDB data directory..."
  mysql_install_db --datadir=/var/lib/mysql

  echo "==> Starting temporary MariaDB for setup..."
  mysqld_safe --datadir="${MYSQL_DATA_DIR}" --port=${DB_PORT} --log-error="${MYSQL_LOG}" &
  sleep 8

  echo "==> Setting MySQL root password..."
  mysql --user=root <<EOF
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASS}');
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

  echo "==> Creating XDMoD database and user..."
  mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${XDMOD_DB} CHARACTER SET utf8;
CREATE USER IF NOT EXISTS '${XDMOD_USER}'@'localhost' IDENTIFIED BY '${XDMOD_PASS}';
GRANT ALL PRIVILEGES ON ${XDMOD_DB}.* TO '${XDMOD_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

  # Note: xdmod-setup must be run manually before first start (see README.md)
  # It requires interactive input and cannot be automated

  # Stop temporary MariaDB
  mysqladmin -u root -p"${MYSQL_ROOT_PASS}" shutdown
fi

# --- Step 3: Start MariaDB in background ---
echo "==> Starting MariaDB..."
mysqld_safe --datadir="${MYSQL_DATA_DIR}" --port=${DB_PORT} --log-error="${MYSQL_LOG}" &

# Wait for MariaDB to become available
echo "==> Waiting for MariaDB to start..."
for i in $(seq 1 30); do
  mysqladmin --port=${DB_PORT} -u root -p"${MYSQL_ROOT_PASS}" ping &>/dev/null && break
  sleep 1
done

# --- Step 4: Generate self-signed SSL certificate if missing ---
SSL_CERT_DIR=/etc/httpd/ssl
SSL_CERT_FILE=${SSL_CERT_DIR}/selfsigned.crt
SSL_KEY_FILE=${SSL_CERT_DIR}/selfsigned.key

if [ ! -f "${SSL_CERT_FILE}" ] || [ ! -f "${SSL_KEY_FILE}" ]; then
  echo "==> Generating self-signed SSL certificate..."
  mkdir -p ${SSL_CERT_DIR}
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ${SSL_KEY_FILE} \
    -out ${SSL_CERT_FILE} \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
    >/dev/null 2>&1
  echo "==> Self-signed certificate created at ${SSL_CERT_FILE}"
fi

# --- Step 5: Start php-fpm ---
echo "==> Starting php-fpm..."
/usr/sbin/php-fpm --nodaemonize &

# --- Step 6: Start Apache in foreground ---
echo "==> Starting Apache web server (HTTP on port 8089, HTTPS on port 8443)..."
httpd -DFOREGROUND
