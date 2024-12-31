#!/bin/bash

# mytop-lite: A lightweight MariaDB/MySQL monitoring tool

# Configuration
DB_USER="root"      # Default database username
DB_PASS=""          # Default database password (use an empty string for prompting securely)
DB_HOST="localhost" # Default host
REFRESH_INTERVAL=2  # Refresh interval in seconds

# Check if mysql or mariadb is installed
if ! command -v mysql &>/dev/null && ! command -v mariadb &>/dev/null; then
  echo "Error: Neither mysql nor mariadb command found. Please install MySQL or MariaDB client."
  exit 1
fi

# Determine which command to use
if command -v mysql &>/dev/null; then
  MYSQL_CMD="mysql"
elif command -v mariadb &>/dev/null; then
  MYSQL_CMD="mariadb"
fi

# Prompt for credentials if not set
if [ -z "$DB_PASS" ]; then
  read -r -s -p "Enter MySQL Password: " DB_PASS
  echo
fi

# Function to fetch and display metrics
function display_metrics() {
  clear
  echo "MySQL Monitor (mytop-lite) - Refreshing every $REFRESH_INTERVAL seconds"
  echo "------------------------------------------------------------"

  # Show server connections
  echo "[Connection Statistics]"
  $MYSQL_CMD -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -e "SHOW STATUS LIKE 'Threads_connected';" | awk 'NR==2 {print "Threads Connected: "$2}'
  $MYSQL_CMD -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -e "SHOW STATUS LIKE 'Threads_running';" | awk 'NR==2 {print "Threads Running: "$2}'

  # Show running queries
  printf "\n[Running Queries]\n"
  $MYSQL_CMD -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -e "SHOW FULL PROCESSLIST;" | awk 'NR==1 || $2 != "" {print $0}'

  # Show database sizes
  printf "\n[Database Sizes (MB)]\n"
  $MYSQL_CMD -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -e "\
      SELECT table_schema AS 'Database', \
             ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' \
      FROM information_schema.tables \
      GROUP BY table_schema;"

  # Query performance metrics
  printf "\n[Performance Metrics]\n"
  $MYSQL_CMD -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('Questions', 'Slow_queries', 'Uptime');" | awk '{print $1": "$2}'

  echo "------------------------------------------------------------"
  echo "Press Ctrl+C to exit."
}

# Main loop to refresh metrics
while true; do
  display_metrics
  sleep $REFRESH_INTERVAL
done
