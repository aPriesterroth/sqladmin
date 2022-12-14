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
 │     DESCRIPTION:  This procedure sets the recovery model of every user database to a specific  │
 │    ─────────────  option. The options are FULL, BULK_LOGGED, or SIMPLE.                        │
 │                                                                                                │
 │                   If no recovery model option is specified, the option FULL will be used.      │
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

CREATE OR ALTER   PROCEDURE [dbo].[usp_set_recovery_model]
       @recovery_model NVARCHAR(100) = 'FULL'
AS
BEGIN
       SET NOCOUNT ON;

       DECLARE @sql     NVARCHAR(MAX);
       DECLARE @db_name NVARCHAR(MAX);

       IF (@recovery_model IN ('FULL', 'BULK_LOGGED', 'SIMPLE'))
       BEGIN
             SELECT [name] INTO [#dbs] FROM [sys].[databases] WHERE [database_id] > 4 AND [recovery_model_desc] <> @recovery_model AND [name] NOT IN (SELECT [database_name]  FROM sys.dm_hadr_availability_group_states States 
																	INNER JOIN master.sys.availability_groups Groups ON States.group_id = Groups.group_id
																	INNER JOIN sys.availability_databases_cluster AGDatabases ON Groups.group_id = AGDatabases.group_id
																	WHERE primary_replica != @@Servername);


             WHILE(EXISTS(SELECT 1 FROM #dbs))
             BEGIN
                    SET @db_name = (SELECT TOP(1) [name] FROM [#dbs] ORDER BY [name]);

                    SET @sql = 'USE [master]; ALTER DATABASE ' + QUOTENAME(@db_name) + ' SET RECOVERY ' + @recovery_model + ' WITH NO_WAIT;';
                    EXEC sp_executesql @sql;

                    DELETE FROM [#dbs] WHERE [name] = @db_name;
             END;

             DROP TABLE [#dbs];

       END;
       ELSE
       BEGIN
             PRINT '
ERROR:
Recovery model ' + QUOTENAME(@recovery_model) + ' is unknown.';
       END;
END
GO
