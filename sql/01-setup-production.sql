-- Run with: sqlcmd -S . -E -i 01-setup-production.sql -v AppPassword="<strong-password>"
-- 1) Dedicated login (never use sa)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ElearningApp')
  CREATE LOGIN [ElearningApp] WITH PASSWORD = '$(AppPassword)', CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
GO
USE [ElearningDB];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ElearningApp')
  CREATE USER [ElearningApp] FOR LOGIN [ElearningApp];
GO
-- 2) Least privilege
ALTER ROLE [db_datareader] ADD MEMBER [ElearningApp];
ALTER ROLE [db_datawriter] ADD MEMBER [ElearningApp];
GRANT EXECUTE TO [ElearningApp];
GO
-- 3) Recovery model FULL + initial full backup (required before log backups work)
ALTER DATABASE [ElearningDB] SET RECOVERY FULL;
GO
-- 4) Instance settings (adjust Max memory to ~75-80% of server RAM; example for 8 GB box)
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'max server memory (MB)', 6144; RECONFIGURE;
EXEC sp_configure 'max degree of parallelism', 4; RECONFIGURE;
EXEC sp_configure 'cost threshold for parallelism', 50; RECONFIGURE;
GO
