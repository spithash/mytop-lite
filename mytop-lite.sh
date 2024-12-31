#!/bin/bash

# Define color codes
BLUE='\e[0;34m'
CYAN='\e[0;36m'
YELLOW='\e[0;33m'
RESET='\e[0m'  # Reset to default color

# Prompt for MySQL/MariaDB Credentials
echo -n "Enter MySQL/MariaDB root password: "
read -s MYSQL_PASSWORD
echo

# Check for MySQL or MariaDB command
if command -v mysql &> /dev/null; then
    MYSQL_CMD="mysql"
elif command -v mariadb &> /dev/null; then
    MYSQL_CMD="mariadb"
else
    echo "MySQL/MariaDB command not found. Please install MySQL or MariaDB."
    exit 1
fi

# Function to format bytes into a human-readable format (MB, GB)
bytes_to_human_readable() {
    local size=$1
    if [ "$size" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $size/1073741824" | bc) GB"
    elif [ "$size" -ge 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc) MB"
    elif [ "$size" -ge 1024 ]; then
        echo "$(echo "scale=2; $size/1024" | bc) KB"
    else
        echo "$size B"
    fi
}

# Function to fetch MySQL/MariaDB stats
fetch_mysql_stats() {
    # Get Threads Connected and Max Connections
    threads_connected=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SHOW STATUS LIKE 'Threads_connected';" | awk 'NR==2 {print $2}')
    max_connections=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SHOW VARIABLES LIKE 'max_connections';" | awk 'NR==2 {print $2}')

    # Get Active Processes (without truncating) and format output
    active_processes=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SHOW PROCESSLIST;")
    
    # Get Database Sizes (only once)
    database_sizes=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SELECT table_schema AS 'Database', SUM(data_length + index_length) / 1024 / 1024 AS 'Size (MB)' FROM information_schema.tables GROUP BY table_schema;")

    # Get Server Metrics
    queries=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SHOW STATUS LIKE 'Questions';" | awk 'NR==2 {print $2}')
    slow_queries=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SHOW STATUS LIKE 'Slow_queries';" | awk 'NR==2 {print $2}')
    uptime=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SHOW VARIABLES LIKE 'Uptime';" | awk 'NR==2 {print $2}')
    open_tables=$($MYSQL_CMD -u root -p"$MYSQL_PASSWORD" -e "SHOW STATUS LIKE 'Open_tables';" | awk 'NR==2 {print $2}')

    # Get the PID of MySQL/MariaDB
    pid=$(pgrep -o -f mysqld)

    # If MySQL/MariaDB is not found, try the mariadb process name
    if [ -z "$pid" ]; then
        pid=$(pgrep -o -f mariadbd)
    fi

    # If still not found, exit
    if [ -z "$pid" ]; then
        echo "MySQL/MariaDB is not running."
        exit 1
    fi

    # Fetch CPU usage of MySQL/MariaDB (Check mysqld, mariadbd, mysql)
    cpu_usage=$(top -b -n1 -p "$pid" | grep -E 'mysqld|mariadbd|mysql' | awk '{print $9}')

    # Fetch memory usage from /proc
    mem_usage=$(grep VmRSS /proc/"$pid"/status | awk '{print $2}')

    # Handle possible null or empty values
    if [ -z "$cpu_usage" ]; then
        cpu_usage="N/A"
    fi

    if [ -z "$mem_usage" ]; then
        mem_usage="N/A"
    fi

    # Output Results with Colors and better formatting

    # Header
    echo -e "${CYAN}MySQL/MariaDB Metrics${RESET}"
    echo -e "${CYAN}------------------------------------------${RESET}"

    # Threads and Connections
    echo -e "${YELLOW}Threads Connected:${RESET} $threads_connected ${YELLOW}/ Max Connections:${RESET} $max_connections"
    echo -e "${CYAN}------------------------------------------${RESET}"

    # Active Processes formatted like `btop`
    echo -e "${CYAN}Active Processes:${RESET}"
    echo -e "ID       User            Host          DB           Command    Time    State              Info"
    echo -e "${CYAN}------------------------------------------${RESET}"
    echo "$active_processes" | awk 'NR>1 {print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12}' | \
    while read -r id user host db command time state info; do
        printf "%-8s %-15s %-15s %-15s %-12s %-6s %-18s %-s\n" "$id" "$user" "$host" "$db" "$command" "$time" "$state" "$info"
    done

    # Database Sizes
    echo -e "${CYAN}------------------------------------------${RESET}"
    echo -e "${CYAN}Database Sizes (MB):${RESET}"
    echo "$database_sizes" | while read -r db size; do
        printf "%-25s %s MB\n" "$db" "$size"
    done

    # MySQL/MariaDB Server Metrics
    echo -e "${CYAN}------------------------------------------${RESET}"
    echo -e "${CYAN}MySQL/MariaDB Server Metrics:${RESET}"
    echo -e "Queries: $queries"
    echo -e "Slow Queries: $slow_queries"
    echo -e "Uptime: $uptime seconds"
    echo -e "Open Tables: $open_tables"
    echo -e "${CYAN}------------------------------------------${RESET}"

    # CPU and Memory Usage
    echo -e "${CYAN}MySQL/MariaDB CPU and Memory Usage:${RESET} $cpu_usage % CPU, $(bytes_to_human_readable $mem_usage) Memory"
    echo -e "${CYAN}------------------------------------------${RESET}"

    echo -e "${CYAN}Press Ctrl+C to exit.${RESET}"
}

# Main loop
while true; do
    clear
    fetch_mysql_stats
    sleep 2  # Refresh every 2 seconds
done
