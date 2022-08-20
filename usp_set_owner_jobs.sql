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
 │    ─────────────  every agent job.                                                             │
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

CREATE OR ALTER   PROCEDURE [dbo].[usp_set_owner_job]
	@job_owner_new NVARCHAR(MAX) = 'sa'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql      NVARCHAR(MAX);
	DECLARE @job_name NVARCHAR(MAX);

	IF (EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] = @job_owner_new))
	BEGIN
		--
		SELECT [name] INTO [#jobs] FROM [msdb].[dbo].[sysjobs] WHERE [owner_sid] <> SUSER_SID(@job_owner_new);

		WHILE(EXISTS(SELECT 1 FROM [#jobs]))
		BEGIN
			SET @job_name = (SELECT TOP(1) [name] FROM [#jobs] ORDER BY [name]);

			SET @sql = 'USE [msdb]; EXEC [msdb].[dbo].[sp_update_job] @job_name=''' + @job_name + ''', @owner_login_name=''' + @job_owner_new + ''';';
			EXEC sp_executesql @sql

			DELETE FROM [#jobs] WHERE [name] = @job_name;
		END;
		
		DROP TABLE [#jobs];
	END;
	ELSE
	BEGIN
		PRINT '
ERROR:
The login name ' + QUOTENAME(@job_owner_new) + ' could not be found.';
	END;
END
GO