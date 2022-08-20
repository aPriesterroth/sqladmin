
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
 │     DESCRIPTION:  This procedure sets the query store of every user database to a specific     │
 │    ─────────────  option. The options are READ_WRITE, READ_ONLY, or OFF.                       │
 │                                                                                                │
 │                   If no page verify option is specified, the option READ_WRITE will be used.   │
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

CREATE OR ALTER       PROCEDURE [dbo].[usp_set_query_store]
	@operation_mode NVARCHAR(MAX) = 'READ_WRITE'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql     NVARCHAR(MAX);
	DECLARE @out	 NVARCHAR(MAX);
	DECLARE @db_name NVARCHAR(MAX);

	IF (@operation_mode IN ('READ_WRITE', 'READ_ONLY', 'OFF'))
	BEGIN
		SELECT [name] INTO [#dbs] FROM [sys].[databases] WHERE [database_id] > 4;

		WHILE(EXISTS(SELECT 1 FROM #dbs))
		BEGIN
			SET @db_name = (SELECT TOP(1) [name] FROM [#dbs] ORDER BY [name]);

			-- Check the state of the query store for the current database
			SET @sql = 'USE ' + QUOTENAME(@db_name) + '; SELECT TOP(1) @out = [desired_state_desc] FROM [sys].[database_query_store_options];'
			EXEC sp_executesql @query = @sql, @params = N'@out NVARCHAR(MAX) OUTPUT', @out = @out OUTPUT
			
			-- If the current mode does not match the operation mode specified by the user
			IF (@operation_mode <> @out)
			BEGIN
				-- Enable/disbale the databases query store
				SET @sql = 'USE [master]; ALTER DATABASE ' + QUOTENAME(@db_name) + ' SET QUERY_STORE = ' + (CASE WHEN @operation_mode = 'OFF' THEN 'OFF' ELSE 'ON' END) + ';';
				EXEC sp_executesql @sql;

				-- If not turning off the query store
				IF (@operation_mode <> 'OFF')
				BEGIN
					-- Set the specified operation mode
					SET @sql = 'USE [master]; ALTER DATABASE ' + QUOTENAME(@db_name) + ' SET QUERY_STORE (OPERATION_MODE = ' + @operation_mode + ');'
					EXEC sp_executesql @sql;
				END;
			END;
			
			DELETE FROM [#dbs] WHERE [name] = @db_name;
		END;

		DROP TABLE [#dbs];
	END;
	ELSE
	BEGIN
		PRINT '
ERROR:
Operation mode ' + QUOTENAME(@operation_mode) + ' is unknown.';
	END;
END
GO


