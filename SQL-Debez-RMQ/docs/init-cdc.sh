#!/bin/bash

# Initialize SQL Server CDC
# This script enables CDC on the database and creates necessary tables

MSSQL_HOST=${MSSQL_HOST:-"localhost"}
MSSQL_PORT=${MSSQL_PORT:-1433}
SA_PASSWORD=${SA_PASSWORD:-"YourSecureP@ssw0rd!"}

echo "Initializing SQL Server CDC..."
echo "Host: $MSSQL_HOST:$MSSQL_PORT"

# Check if sqlcmd is available
if ! command -v sqlcmd &> /dev/null; then
    echo "Error: sqlcmd not found. Please install SQL Server Command Line Tools."
    exit 1
fi

# Connect and initialize
sqlcmd -S "$MSSQL_HOST,$MSSQL_PORT" -U sa -P "$SA_PASSWORD" -i ../debezium/init-cdc.sql

if [ $? -eq 0 ]; then
    echo "CDC initialization completed successfully!"
else
    echo "Error during CDC initialization"
    exit 1
fi
