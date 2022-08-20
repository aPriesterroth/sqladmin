SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*

 ╭────────────────────────────────────────────────────────────────────────────────────────────────╮
 │                                                                                                │
 │          AUTHOR:  Aaron Priesterroth                                                           │
 │         ────────                                                                               │
 │                                                                                                │
 │     CREATE DATE:  20/08/2022                                                                   │
 │    ─────────────                                                                               │
 │                                                                                                │
 │     DESCRIPTION:  This procedure sets a specific server principal (login) as the owner of      │
 │    ─────────────  every user database and adds the previous owner of the database to the       │
 │                   db_owner role, ensuring no loss of permission due to the change in           │
 │                   ownership.                                                                   │
 │                                                                                                │
 │                   If no server principal is specified, the 'sa' login is used.                 │
 │                                                                                                │
 ├────────────────────────────────────────────────────────────────────────────────────────────────┤
 │                                                                                                │
 │                                                                                                │
 │  CHANGE HISTORY:                                                                               │
 │  ───────────────                                                                               │
 │                                                                                                │
 │                                                                                                │
 │    DATE          AUTHOR                            COMMENT                                     │
 │   ────────────  ───────────────────────────────── ──────────────────────────────────────────   │
 │    2022-08-20    Aaron Priesterroth                Initial creation.                           │
 │                                                                                                │
 │                                                                                                │
 ╰────────────────────────────────────────────────────────────────────────────────────────────────╯

*/

CREATE OR ALTER   PROCEDURE [dbo].[usp_set_owner_db]
	@db_owner_new NVARCHAR(MAX) = 'sa'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql      NVARCHAR(MAX);
	DECLARE @out      NVARCHAR(MAX);
	DECLARE @db_name  NVARCHAR(MAX);
	DECLARE @db_owner NVARCHAR(MAX);

	IF (EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] = @db_owner_new))
	BEGIN
		-- Select all user databases that are not owned by the server principal specified
		SELECT [name], [owner_sid] INTO [#dbs] FROM [sys].[databases] WHERE [database_id] > 4 AND [owner_sid] <> SUSER_SID(@db_owner_new);

		WHILE(EXISTS(SELECT 1 FROM [#dbs]))
		BEGIN
			-- Retrieve the next database of the list of user databases
			SET @db_name = (SELECT TOP(1) [name] FROM [#dbs] ORDER BY [name]);
			-- Retrieve the name of the current owner of the database
			SET @db_owner = (SELECT TOP(1) SUSER_SNAME([owner_sid]) FROM [#dbs] WHERE [name] = @db_name);

			-- Check if the new owner of the database already has a corresponding database user
			SET @sql = 'USE ' + QUOTENAME(@db_name) + '; SELECT TOP(1) @out = [name] FROM [sys].[database_principals] WHERE [name] = ''' + @db_owner_new + ''';'; 
			EXEC sp_executesql @Query = @sql, @Params = N'@out NVARCHAR(MAX) OUT', @out = @out OUTPUT
			
			IF (@out IS NOT NULL) -- The new database owner already has a user in the database
			BEGIN
				SET @sql = 'USE ' + QUOTENAME(@db_name) + '; DROP USER ' + QUOTENAME(@db_owner_new) + ';';
				EXEC sp_executesql @sql;
			END;

			-- Set ownership of the database to new database owner
			SET @sql = 'USE ' + QUOTENAME(@db_name) + '; ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(@db_name) + ' TO ' + QUOTENAME(@db_owner_new) + ';';
			EXEC sp_executesql @sql;

			-- Add previous owner to db_owner role of database, not possible for 'sa'
			IF (@db_owner <> 'sa')
			BEGIN
				SET @sql = 'USE ' + QUOTENAME(@db_name) + '; CREATE USER ' + QUOTENAME(@db_owner) + ' FOR LOGIN ' + QUOTENAME(@db_owner) + ';';
				EXEC sp_executesql @sql;

				SET @sql = 'USE ' + QUOTENAME(@db_name) + '; ALTER ROLE [db_owner] ADD MEMBER ' + QUOTENAME(@db_owner) + ';';
				EXEC sp_executesql @sql;
			END;

			DELETE FROM [#dbs] WHERE [name] = @db_name;
		END;
		
		DROP TABLE [#dbs];
	END;
	ELSE
	BEGIN
		PRINT '
ERROR:
The login name ' + QUOTENAME(@db_owner_new) + ' could not be found.';
	END;
END
GO


