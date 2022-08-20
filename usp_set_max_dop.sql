
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
 │     DESCRIPTION:  This procedure sets the maximum degree of parallelism (DOP) and parallelism  │
 │    ─────────────  threshold for the instance and every user database. Individual execution of  │
 │                   setting the instances DOP, threshold, user database DOP or secondary DOP can │
 │                   be controlled with the parameters @set_threshold, @set_dop, @set_db_dop,     │
 │                   @set_db_dop, and @set_db_dop_sec.                                            │
 │                                                                                                │
 │                   If no cost threshold is set, a threshold of 50 will be used.                 │
 │                                                                                                │
 │                   If no maximum degree of parallelism is set, a calculated limit based on the  │
 │                   number of cores available to the instance will be used.                      │
 │                                                                                                │
 │                   If no maximum degree of parallelism for user databases is set, the DOP limit │
 │                   of the instance will be used.                                                │
 │                                                                                                │
 │                   IF no secondary maximum degree of parallelism for user databases is set, the │
 │                   primary limit of the database will be used.                                  │
 │                                                                                                │
 │                   By default, all available configuration options will be executed.            │
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

CREATE OR ALTER PROCEDURE [dbo].[usp_set_max_dop]
	@cost_threshold INT = 50,
	@max_dop        INT = NULL,
	@max_dop_db     INT = 0,
	@max_dop_db_sec INT = NULL,
	@set_threshold  BIT = 1,
	@set_dop        BIT = 1,
	@set_db_dop     BIT = 1,
	@set_db_dop_sec BIT = 1
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql     NVARCHAR(MAX);
	DECLARE @db_name NVARCHAR(MAX);

	-- Enable advanced options and reconfigure instance if threshold or max dop is set
	IF (@set_threshold = 1 OR @set_dop = 1)
	BEGIN
		SET @sql = 'USE [master]; EXEC [sys].[sp_configure] ''show advanced option'', ''1'''
		EXEC sp_executesql @sql;
		SET @sql = 'USE [master]; RECONFIGURE WITH OVERRIDE';
		EXEC sp_executesql @sql;
	END;

	-- Set parallelism threshold
	IF (@set_threshold = 1)
	BEGIN
		SET @sql = 'USE [master]; EXEC [sys].[sp_configure] ''cost threshold for parallelism'', ''' + (CAST(@cost_threshold AS NVARCHAR(MAX))) + '''';
		EXEC sp_executesql @sql;
	END

	-- Set max degree of parallelism
	IF (@set_dop = 1)
	BEGIN
		IF (@max_dop IS NULL)
		BEGIN
			-- Set max dop based on instance core count
			SELECT @max_dop = (SELECT CAST([cpu_count] AS INT) FROM [sys].[dm_os_sys_info]);
		END

		SET @sql = 'USE [master]; EXEC [sys].[sp_configure] ''max degree of parallelism'', ''' + (CAST(@max_dop AS NVARCHAR(MAX))) + '''';
		EXEC sp_executesql @sql;
	END;

	-- Disable advanced options and reconfigure
	IF (@set_threshold = 1 OR @set_dop = 1)
	BEGIN
		SET @sql = 'USE [master]; EXEC [sys].[sp_configure] ''show advanced option'', ''0'''
		EXEC sp_executesql @sql;
		SET @sql = 'USE [master]; RECONFIGURE WITH OVERRIDE';
		EXEC sp_executesql @sql;
	END;

	-- Set max dop and secondary max dop for every user database
	IF (@set_db_dop = 1 OR @set_db_dop_sec = 1)
	BEGIN
		SELECT [name] INTO [#dbs] FROM [sys].[databases] WHERE [database_id] > 4;

		WHILE(EXISTS(SELECT 1 FROM #dbs))
		BEGIN
			SET @db_name = (SELECT TOP(1) [name] FROM [#dbs] ORDER BY [name]);
			
			IF (@set_db_dop = 1)
			BEGIN
				SET @sql = 'USE ' + QUOTENAME(@db_name) + '; ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = ' + (CASE WHEN @max_dop_db IS NULL THEN '0' ELSE (CAST(@max_dop_db AS NVARCHAR(MAX))) END) + ';'
				EXEC sp_executesql @sql;
			END;

			IF (@set_db_dop_sec = 1)
			BEGIN
				SET @sql = 'USE ' + QUOTENAME(@db_name) + '; ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = ' + (CASE WHEN @max_dop_db_sec IS NULL THEN 'PRIMARY' ELSE (CAST(@max_dop_db_sec AS NVARCHAR(MAX))) END) + ';'
				EXEC sp_executesql @sql;
			END;
			
			DELETE FROM [#dbs] WHERE [name] = @db_name;
		END;

		DROP TABLE [#dbs];
	END;
END
GO