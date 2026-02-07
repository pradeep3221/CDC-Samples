-- Initialize CDC on SQL Server
-- Run this script on the SQL Server instance as SA

-- Create test database
CREATE DATABASE testdb;
GO

USE testdb;
GO

-- Enable CDC at database level
EXEC sys.sp_cdc_enable_db;
GO

-- Create sample table
CREATE TABLE dbo.Customers (
    CustomerId INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100),
    PhoneNumber NVARCHAR(20),
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
GO

-- Enable CDC on the table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'Customers',
    @role_name = NULL,
    @supports_net_changes = 1;
GO

-- Insert sample data
INSERT INTO dbo.Customers (FirstName, LastName, Email, PhoneNumber)
VALUES 
    ('John', 'Doe', 'john.doe@example.com', '555-0101'),
    ('Jane', 'Smith', 'jane.smith@example.com', '555-0102'),
    ('Bob', 'Johnson', 'bob.johnson@example.com', '555-0103');
GO

-- Create login for Debezium
CREATE LOGIN debezium WITH PASSWORD = 'YourSecureP@ssw0rd!';
GO

-- Grant necessary permissions
USE testdb;
GO

CREATE USER debezium FOR LOGIN debezium;
GO

-- Grant SELECT on CDC tables
GRANT SELECT ON cdc.dbo_Customers_CT TO debezium;
GO

-- Grant VIEW_DEFINITION permission
GRANT VIEW DEFINITION ON DATABASE::testdb TO debezium;
GO

-- Grant SELECT on system tables
GRANT SELECT ON sys.databases TO debezium;
GO
