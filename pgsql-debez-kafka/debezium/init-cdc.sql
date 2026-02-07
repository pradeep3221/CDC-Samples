-- Initialize CDC on PostgreSQL
-- Run this script on the PostgreSQL instance

-- Create test database if not exists
CREATE DATABASE testdb;

-- Connect to testdb
\c testdb;

-- Enable logical replication
ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM SET max_wal_senders = 10;
ALTER SYSTEM SET max_replication_slots = 10;

-- Create replication role
CREATE ROLE debezium WITH REPLICATION LOGIN PASSWORD 'postgres-password';

-- Create sample table
CREATE TABLE IF NOT EXISTS public.customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone_number VARCHAR(20),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grant permissions
GRANT CONNECT ON DATABASE testdb TO debezium;
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO debezium;

-- Insert sample data
INSERT INTO public.customers (first_name, last_name, email, phone_number)
VALUES 
    ('John', 'Doe', 'john.doe@example.com', '555-0101'),
    ('Jane', 'Smith', 'jane.smith@example.com', '555-0102'),
    ('Bob', 'Johnson', 'bob.johnson@example.com', '555-0103')
ON CONFLICT DO NOTHING;

-- Create publication for CDC
CREATE PUBLICATION IF NOT EXISTS dbz_publication FOR ALL TABLES;

-- Create replication slot (will be created by Debezium connector)
-- SELECT * FROM pg_create_logical_replication_slot('debezium_slot', 'pgoutput');
