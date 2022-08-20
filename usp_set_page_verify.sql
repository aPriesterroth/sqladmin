
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
 │     DESCRIPTION:  This procedure sets the page verify option of all user databases to a        │
 │    ─────────────  specific value. Values are CHECKSUM, TORN_PAGE_DETECTION, or NONE.           │
 │                                                                                                │
 │                   If no page verify option is specified, the option CHECKSUM will be used.     │
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

CREATE OR ALTER   PROCEDURE [dbo].[usp_set_page_verify]
	@page_verify_option NVARCHAR(MAX) = 'CHECKSUM'
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @sql     NVARCHAR(MAX);
	DECLARE @out	 NVARCHAR(MAX);
	DECLARE @db_name NVARCHAR(MAX);

	IF (@page_verify_option IN ('CHECKSUM', 'TORN_PAGE_DETECTION', 'NONE'))
	BEGIN
	   	SELECT [name] INTO [#dbs] FROM [sys].[databases] WHERE [database_id] > 4 AND page_verify_option_desc <> @page_verify_option;

		WHILE(EXISTS(SELECT 1 FROM #dbs))
		BEGIN
			SET @db_name = (SELECT TOP(1) [name] FROM [#dbs] ORDER BY [name]);

			SET @sql = 'ALTER DATABASE ' + QUOTENAME(@db_name) + ' SET PAGE_VERIFY CHECKSUM WITH NO_WAIT;';
			EXEC sp_executesql @sql;
			
			DELETE FROM [#dbs] WHERE [name] = @db_name;
		END;

		DROP TABLE [#dbs];
	END;
	ELSE
	BEGIN
		PRINT '
ERROR:
Page verify option ' + QUOTENAME(@page_verify_option) + ' is unknown.';
	END;

END
GO


