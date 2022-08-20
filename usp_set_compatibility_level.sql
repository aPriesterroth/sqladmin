
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*

  Nowember2022?

 ╭────────────────────────────────────────────────────────────────────────────────────────────────╮
 │                                                                                                │
 │          AUTHOR:  Aaron Priesterroth                                                           │
 │         ────────                                                                               │
 │                                                                                                │
 │     CREATE DATE:  20/08/2022                                                                   │
 │    ─────────────                                                                               │
 │                                                                                                │
 │     DESCRIPTION:  This procedure sets the compatibility level of all user databases to a       │
 │    ─────────────  specific value. Databases to be excluded can be specified with the           │
 │	                 @excluded_databases parameter. Database Names need to be supplied as a       │
 │					 comma-separated list of names: E.g.: 'Database1,Database2,Database3'.        │
 │                                                                                                │
 │                   If no compatibility level is specified, level 150 (= 2019) will be used.     │
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

CREATE OR ALTER     PROCEDURE [dbo].[usp_set_compatibility_level]
	@compatibility_level INT = 150,
	@excluded_databases NVARCHAR(MAX) = ''
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql     NVARCHAR(MAX);
	DECLARE @db_name NVARCHAR(MAX);

	CREATE TABLE #dbs_ex (
		[database] NVARCHAR(MAX) NOT NULL
	);

	-- Retrieve the names of databases to exclude into a temp table
	IF (@excluded_databases IS NOT NULL) 
	BEGIN
		INSERT INTO #dbs_ex ([database]) SELECT * FROM STRING_SPLIT(@excluded_databases, ',');
	END;

	IF (@compatibility_level IN (150, 140, 130, 120, 110, 100))
	BEGIN
		SELECT [name] INTO [#dbs] FROM [sys].[databases] WHERE [database_id] > 4 AND [compatibility_level] <> @compatibility_level AND [name] NOT IN (SELECT * FROM #dbs_ex);

		WHILE(EXISTS(SELECT 1 FROM #dbs))
		BEGIN
			SET @db_name = (SELECT TOP(1) [name] FROM [#dbs] ORDER BY [name]);

			SET @sql = 'USE [master]; ALTER DATABASE ' + QUOTENAME(@db_name) + ' SET COMPATIBILITY_LEVEL = ' + STR(@compatibility_level) + ';';
			EXEC sp_executesql @sql;

			DELETE FROM [#dbs] WHERE [name] = @db_name;
		END;

		DROP TABLE [#dbs];
		DROP TABLE [#dbs_ex];
	END;
	ELSE
	BEGIN
		PRINT '
ERROR:
Compatibility level ' + QUOTENAME(@compatibility_level) + ' is invalid.';
	END;
END
GO


