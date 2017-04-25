/*
 ============================================================================
DISCLAIMER: 
	This code and information are provided "AS IS" without warranty of any kind,
	either expressed or implied, including but not limited to the implied 
	warranties or merchantability and/or fitness for a particular purpose.
 ============================================================================
LICENSE: 
	This script is free to download and use for personal, educational, 
	and internal corporate purposes, provided that this header is preserved. 
	Redistribution or sale of this script, in whole or in part, is 
	prohibited without the author's express written consent.
 ============================================================================
*/
USE [master];
GO
-- install configuration recommendations by John Eisbrener
-- https://dbaeyes.wordpress.com/2011/08/18/hooray-you-finished-installing-sql-server-now-what/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

---------------------------------------------------------------------
--					D e c l a r a t  i o n 
---------------------------------------------------------------------
DECLARE @DB_Exclude TABLE ( DatabaseName sysname );
IF OBJECT_ID('tempdb..#ExcludeDB') IS NOT NULL DROP TABLE #ExcludeDB;
CREATE TABLE #ExcludeDB([name] sysname NOT NULL);
IF OBJECT_ID('tempdb..#SharePointDB') IS NOT NULL DROP TABLE #SharePointDB;
CREATE TABLE #SharePointDB([name] sysname NOT NULL);
DECLARE @IsCRMDynamicsON BIT;
DECLARE @error NVARCHAR(2048);
DECLARE @cmd NVARCHAR(MAX);
DECLARE @SharePointAG TABLE
    (
      [Type] sysname ,
      DatabaseName sysname ,
      Script NVARCHAR(MAX)
    );
DECLARE @MajorVersion INT;
IF OBJECT_ID('tempdb..#checkversion') IS NOT NULL
    DROP TABLE #checkversion;
CREATE TABLE #checkversion
    (
      version NVARCHAR(128) ,
      common_version AS SUBSTRING(version, 1, CHARINDEX('.', version) + 1) ,
      major AS PARSENAME(CONVERT(VARCHAR(32), version), 4) ,
      minor AS PARSENAME(CONVERT(VARCHAR(32), version), 3) ,
      build AS PARSENAME(CONVERT(VARCHAR(32), version), 2) ,
      revision AS PARSENAME(CONVERT(VARCHAR(32), version), 1)
    );

IF OBJECT_ID('tempdb..#dm_server_registry') IS NOT NULL
    DROP TABLE #dm_server_registry;
CREATE TABLE #dm_server_registry
    (
      [Type] VARCHAR(250) ,
      [Database Name] sysname ,
      Script NVARCHAR(MAX)
    );
IF OBJECT_ID('tempdb..#TraceFlag') IS NOT NULL
    DROP TABLE #TraceFlag;
CREATE TABLE #TraceFlag
    (
      TraceFlag INT ,
      [Status] INT ,
      [Global] INT ,
      [Session] INT
    );
DECLARE @ver NVARCHAR(128);
DECLARE @key VARCHAR(8000);
DECLARE @ComptabilityLevel NVARCHAR(128);
DECLARE @InstanceNames NVARCHAR(100);
DECLARE @reg TABLE
    (
      keyname CHAR(200) ,
      value VARCHAR(1000)
    );
DECLARE @Tempreg TABLE
    (
      keyname CHAR(200) ,
      value VARCHAR(1000)
    );
IF OBJECT_ID('tempdb..#SR_reg') IS NOT NULL
    DROP TABLE #SR_reg;
CREATE TABLE #SR_reg
    (
      Service VARCHAR(1000) ,
      InstanceNames VARCHAR(1000) ,
      keyname CHAR(200) ,
      value VARCHAR(1000) ,
      CurrentInstance AS CASE WHEN InstanceNames = @@SERVICENAME
                              THEN CONVERT(BIT, 1)
                              ELSE CONVERT(BIT, 0)
                         END
    );
DECLARE @keyi VARCHAR(8000);
 -- Holds Registry Key Value
             
DECLARE @SQLServiceNamei VARCHAR(8000);
DECLARE @AgentServiceNamei VARCHAR(8000);

---------------------------------------------------------------------
--							CRM Dynamics
---------------------------------------------------------------------
INSERT  @DB_Exclude
        SELECT  D.name
        FROM    sys.databases D
        WHERE   D.name IN ( 'MSCRM_CONFIG', 'OrganizationName_MSCRM' );

SET @IsCRMDynamicsON = 0;
SELECT TOP 1
        @IsCRMDynamicsON = 1
FROM    sys.server_principals SP
WHERE   SP.name = 'MSCRMSqlLogin';
IF @IsCRMDynamicsON = 0
    SELECT TOP 1
            @IsCRMDynamicsON = 1
    FROM    @DB_Exclude;
---------------------------------------------------------------------
--							BizTalk
---------------------------------------------------------------------
/*
Biztalk:https://blogs.msdn.microsoft.com/blogdoezequiel/2009/01/25/sql-best-practices-for-biztalk/
Auto create statistics must be disabled
Auto update statistics must be disabled
MAXDOP (Max degree of parallelism) must be defined as 1 in both SQL Server 2000 and SQL Server 2005 in the instance in which BizTalkMsgBoxDB database exists
*/
INSERT  @DB_Exclude
        SELECT  D.name
        FROM    sys.databases D
        WHERE   D.name IN ( 'BizTalkMsgBoxDB', 'BizTalkRuleEngineDb', 'SSODB',
                            'BizTalkHWSDb', 'BizTalkEDIDb', 'BAMArchive',
                            'BAMStarSchema', 'BAMPrimaryImport',
                            'BizTalkMgmtDb', 'BizTalkAnalysisDb',
                            'BizTalkTPMDb' );
---------------------------------------------------------------------
--							SharePoint
---------------------------------------------------------------------
INSERT  @DB_Exclude
        EXEC sp_MSforeachdb 'SELECT TOP 1 ''[?]''[DatabaseName]
FROM   [?].sys.database_principals DP
WHERE  DP.type = ''R'' AND DP.name IN (''SPDataAccess'',''SPReadOnly'')';
SET @cmd = N'';
SELECT	@cmd +='
BEGIN TRY
	INSERT #SharePointDB
	SELECT DISTINCT [Name]
	FROM    ' + QUOTENAME([name]) + '.[dbo].[Objects]
	WHERE   [Name] IN ( SELECT  name COLLATE DATABASE_DEFAULT FROM sys.databases ) AND [Status] = 0
	UNION	SELECT ''' + [name] + ''' [SharePointConfig];
END TRY
BEGIN CATCH
END CATCH'
FROM	sys.databases
WHERE	[name] LIKE '%[_]Config';

BEGIN TRY
	EXEC sys.sp_executesql @cmd;
END TRY
BEGIN CATCH
	PRINT @cmd;
	SET @error = ERROR_MESSAGE();
	RAISERROR(@error,16,1) WITH NOWAIT;
END CATCH
IF EXISTS(SELECT TOP 1 1 FROM #SharePointDB)
BEGIN
    INSERT @DB_Exclude SELECT [name] FROM #SharePointDB WHERE [name]  NOT IN (SELECT DatabaseName FROM @DB_Exclude);
END
DROP TABLE #SharePointDB;
---------------------------------------------------------------------
--					Team Foundation Server (TFS)
---------------------------------------------------------------------
/*
TFS DB: https://www.visualstudio.com/en-us/docs/setup-admin/tfs/architecture/sql-server-databases
Understand TFS databases, deployment topologies, and backup: https://www.visualstudio.com/he-il/docs/setup-admin/tfs/admin/backup/backup-db-architecture
Manually install SQL Server for Team Foundation Server: https://www.visualstudio.com/en-us/docs/setup-admin/tfs/install/sql-server/install-sql-server
SQL Server Collation Requirements for Team Foundation Server: https://www.visualstudio.com/en-us/docs/setup-admin/tfs/install/sql-server/collation-requirements
*/
IF DB_ID('Tfs_Configuration') IS NOT NULL
BEGIN
	INSERT  @DB_Exclude
	EXEC sp_MSforeachdb 'SELECT TOP 1 ''?''[DatabaseName]
FROM   [?].sys.database_principals DP
WHERE  DP.type = ''R'' AND DP.name = ''TfsWarehouseDataReader''';

	INSERT  @DB_Exclude
	SELECT	CR.[DisplayName]
	FROM	[Tfs_Configuration].[dbo].[tbl_CatalogResource] CR
			INNER JOIN [Tfs_Configuration].[dbo].[tbl_CatalogResourceType] RC ON RC.Identifier = CR.ResourceType
	WHERE	RC.DisplayName = 'Team Foundation Project Collection Database'
			AND CR.[DisplayName] NOT IN(SELECT DatabaseName FROM @DB_Exclude)
	UNION	SELECT name FROM sys.databases WHERE [name] IN ('TFS_Configuration','TFS_Warehouse','TFS_Analysis') AND state = 0 AND name NOT IN(SELECT DatabaseName FROM @DB_Exclude)
END
---------------------------------------------------------------------
--SELECT * FROM  @DB_Exclude
--SELECT * FROM  #ExcludeDB X


INSERT  INTO #checkversion
        ( version
        )
        SELECT  CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));
SELECT  @MajorVersion = major + CASE WHEN minor = 0 THEN '00'
                                     ELSE minor
                                END
FROM    #checkversion;

IF @MajorVersion > 1050 AND SERVERPROPERTY('IsHadrEnabled') = 1--2012
BEGIN
    INSERT  @SharePointAG EXEC ( '
SELECT  ''SharePoint database''[Type],D.name [dbName],CONCAT(''/*Availability group - '',ag.name,'' conteins '',D.name,'' on asynchronous mode. SharePoint does not support this mode on this DB type.
https://technet.microsoft.com/en-us/library/jj841106.aspx
*/
ALTER AVAILABILITY GROUP '',ag.name,'' MODIFY REPLICA ON '',@@SERVERNAME,'' WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);  '')[Message]
FROM    sys.availability_groups AS ag
        INNER JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id
        INNER JOIN sys.dm_hadr_availability_replica_states AS ar_state ON ar.replica_id = ar_state.replica_id
        INNER JOIN sys.dm_hadr_database_replica_states dr_state ON ag.group_id = dr_state.group_id AND dr_state.replica_id = ar_state.replica_id
              INNER JOIN sys.databases D ON D.database_id = dr_state.database_id
WHERE  (D.name LIKE ''Search[_]Service[_]Application[_]DB[_]%''
              OR D.name LIKE ''SharePoint[_]Admin[_]Content%''
              OR D.name LIKE ''SharePoint[_]Config%''
              OR D.name LIKE ''Search[_]Service[_]Application[_]AnalyticsReportingStoreDB[_]%''
              OR D.name LIKE ''Search[_]Service[_]Application[_]CrawlStoreDB[_]%''
              OR D.name LIKE ''Search[_]Service[_]Application[_]LinkStoreDB[_]%''
              OR D.name LIKE ''SharePoint[_]Logging%''
              OR D.name LIKE ''Application[_]SyncDB[_]%''
              OR D.name LIKE ''SessionStateService[_]%''
              
              )
              AND ar.availability_mode = 0;'
                    );
	EXEC('INSERT	#ExcludeDB
SELECT	d.name
FROM	sys.databases d
		INNER JOIN sys.dm_hadr_availability_replica_states rs ON d.replica_id = rs.replica_id
WHERE	rs.role != 1;');

END;

SET @cmd = 'INSERT #dm_server_registry
SELECT	''TraceFlag'' , @@SERVERNAME,''USE [master]
GO
EXEC xp_instance_regwrite N''''HKEY_LOCAL_MACHINE'''', N''''SOFTWARE\\Microsoft\Microsoft SQL Server\\MSSQL'' + @Ver + ''.'' + @InstanceNames + ''\\MSSQLServer\\Parameters'''', N''''SQLArg'' +CONVERT(VARCHAR(10),N.Num + ROW_NUMBER() OVER (ORDER BY N.Num)) + '''''', REG_SZ, '''''' + M.TraceFlag + '''''''' Script
FROM	(SELECT ''-t1117'' TraceFlag
UNION ALL SELECT ''-t1118''
UNION ALL SELECT ''-t3226''
UNION ALL SELECT ''-t1222'') M
		LEFT JOIN (
					select *
					from sys.dm_server_registry where registry_key = ''HKLM\Software\Microsoft\Microsoft SQL Server\MSSQL'' + @Ver + ''.'' + @InstanceNames + ''\MSSQLServer\Parameters'' and value_name like ''SQLArg%''
					and value_name not in (''SQLArg0'',''SQLArg1'',''SQLArg2'')
					and convert(varchar(20),value_data) like ''-t%'') TF ON CONVERT(VARCHAR(50),TF.value_data) = M.TraceFlag
CROSS JOIN (select top 1 value_name,replace(value_name,''SQLArg'','''') Num from sys.dm_server_registry where registry_key = ''HKLM\Software\Microsoft\Microsoft SQL Server\MSSQL'' + @Ver + ''.'' + @InstanceNames + ''\MSSQLServer\Parameters'' and value_name like ''SQLArg%'' order by value_name desc) N
WHERE	TF.value_data IS NULL;';


INSERT  #TraceFlag EXEC ('DBCC TRACESTATUS(-1)'); 

SET @InstanceNames = @@servicename;
  --BEGIN
--Build Sql Server's full service name
SET @SQLServiceNamei = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                            THEN 'MSSQLSERVER'
                            ELSE 'MSSQL$' + @InstanceNames
                       END; 

SET @keyi = 'SYSTEM\CurrentControlSet\Services\' + @SQLServiceNamei;
DELETE  FROM @reg;  
--MSSQLSERVER Service Account
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'ObjectName';
UPDATE  @reg
SET     keyname = @SQLServiceNamei; 
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Engine' ,
                @InstanceNames ,
                'Account Name' ,
                value
        FROM    @reg;
             
             
             -------------------------------------------------------------------------------
IF @InstanceNames = @@SERVICENAME
    BEGIN
        SET @ver = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR);
        IF ( SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1) = '10' )
            BEGIN
                IF SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver) + 1,
                                       LEN(@ver)), 1,
                             CHARINDEX('.',
                                       SUBSTRING(@ver,
                                                 CHARINDEX('.', @ver) + 1,
                                                 LEN(@ver))) - 1) = '50'
                    SELECT  @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
                            + '_' + SUBSTRING(SUBSTRING(@ver,
                                                        CHARINDEX('.', @ver)
                                                        + 1, LEN(@ver)), 1,
                                              CHARINDEX('.',
                                                        SUBSTRING(@ver,
                                                              CHARINDEX('.',
                                                              @ver) + 1,
                                                              LEN(@ver))) - 1);
                ELSE
                    SELECT  @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1);
            END;
   
        ELSE
            SELECT  @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1);
        IF @ver > '9'
            BEGIN
                EXEC sp_executesql @cmd;
            END;
    END;
                    
SET @keyi = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                 THEN 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver
                      + '.' + @InstanceNames + '\MSSQLServer\CurrentVersion'
                 ELSE 'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\'
                      + @InstanceNames + '\MSSQLServer\CurrentVersion'
            END; 
DELETE  FROM @reg;
DELETE  FROM @Tempreg; 
INSERT  INTO @Tempreg
        EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'CurrentVersion';
                    
SELECT  @ver = value
FROM    @Tempreg;
IF LEN(@ver) > 1
    BEGIN
        SET @ComptabilityLevel = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
            + SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver) + 1, LEN(@ver)),
                        1, 1);
			
        IF ( SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1) = '10' )
            BEGIN
                IF SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver) + 1,
                                       LEN(@ver)), 1,
                             CHARINDEX('.',
                                       SUBSTRING(@ver,
                                                 CHARINDEX('.', @ver) + 1,
                                                 LEN(@ver))) - 1) = '50'
                    SELECT  @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
                            + '_' + SUBSTRING(SUBSTRING(@ver,
                                                        CHARINDEX('.', @ver)
                                                        + 1, LEN(@ver)), 1,
                                              CHARINDEX('.',
                                                        SUBSTRING(@ver,
                                                              CHARINDEX('.',
                                                              @ver) + 1,
                                                              LEN(@ver))) - 1);
                ELSE
                    SELECT  @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1);
            END;
   
        ELSE
            SELECT  @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1);
    END;
ELSE
    SET @ComptabilityLevel = @ver + '0';
----------------------------------------------------------------------------------------------------------------------------------
SET @key = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.'
    + @InstanceNames + '\Setup';
INSERT  @reg
        EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'PatchLevel';
                    
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Engine Version' ,
                @InstanceNames ,
                'Last Version Installed' ,
                value
        FROM    @reg;
----------------------------------------------------------------------------------------------------------------------------------
DELETE  FROM @reg;
SET @keyi = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.'
    + @InstanceNames + '\Setup';
INSERT  INTO @reg
        EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'Edition';
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Engine Edition' ,
                @InstanceNames ,
                'Edition Installed' ,
                value
        FROM    @reg;
----------------------------------------------------------------------------------------------------------------------------------
--Error Log file
DELETE  FROM @reg;
SET @keyi = N'Software\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\MSSQLServer';
INSERT  INTO @reg EXECUTE xp_regread N'HKEY_LOCAL_MACHINE', @keyi, N'NumErrorLogs';
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Number of Error Log files' ,
                @InstanceNames ,
                'Number Error Logs' ,
                value
        FROM    @reg;   
----------------------------------------------------------------------------------------------------------------------------------
DELETE  FROM @reg;
SET @key = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @ComptabilityLevel;
INSERT  INTO @reg
        EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'CustomerFeedback';
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Customer Feedback' ,
                @InstanceNames ,
                'Customer Feedback Enabled' ,
                value
        FROM    @reg;
DELETE  FROM @reg;
INSERT  INTO @reg
        EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'EnableErrorReporting';
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Error Reporting' ,
                @InstanceNames ,
                'Error Reporting Enabled' ,
                value
        FROM    @reg;
----------------------------------------------------------------------------------------------------------------------------------
        --SQLSERVERAGENT Service Account
SET @AgentServiceNamei = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                              THEN 'SQLSERVERAGENT'
                              ELSE 'SQLAgent$' + @InstanceNames
                         END; 
SET @keyi = 'SYSTEM\CurrentControlSet\Services\' + @AgentServiceNamei; 
             
DELETE  FROM @reg;  
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'ObjectName';
       
UPDATE  @reg
SET     keyname = @AgentServiceNamei
WHERE   keyname = 'ObjectName';
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Agent' ,
                @InstanceNames ,
                'Account Name' ,
                value
        FROM    @reg;
-------------------------
        --Windows Power Plan
SET @keyi = 'SYSTEM\ControlSet001\Control\Power\User\PowerSchemes';
--'SOFTWARE\Microsoft\Windows\CurrentVersion\explorer\ControlPanel\NameSpace\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}'; 
             
DELETE  FROM @reg;  
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi,
            'ActivePowerScheme';
--'PreferredPlan';
       
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'Windows Power Plan' ,
                @InstanceNames ,
                'Power Plan' ,
                CASE CONVERT(VARCHAR(50), value)
                  WHEN '381b4222-f694-41f0-9685-ff5bb260df2e' THEN 'Balanced'
                  WHEN 'a1841308-3541-4fab-bc81-f71556f20b4a'
                  THEN 'Power saver'
                  WHEN '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
                  THEN 'High performance'
                  ELSE 'User Preferance'
                END
        FROM    @reg;
-------------------------
DELETE  FROM @reg;  
        
SET @keyi = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                 THEN 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver
                      + '.' + @InstanceNames + '\MSSQLServer\Parameters'
                 ELSE 'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\'
                      + @InstanceNames + '\MSSQLServer\Parameters'
            END; 
DELETE  FROM @reg;  
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs3';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs4';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs5';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs6';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs7';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs8';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs9';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs10';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs11';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs12';
INSERT  INTO @reg
        EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs13';
       
UPDATE  @reg
SET     keyname = @InstanceNames
WHERE   keyname LIKE 'SQLArgs%';
             
INSERT  #SR_reg
        ( Service ,
          InstanceNames ,
          keyname ,
          value
        )
        SELECT  'SQL Server Trace Flage' ,
                @InstanceNames ,
                'Trace Flage' ,
                value
        FROM    @reg;
  
SELECT  'PAGE VERIFY' [Type] ,
        db.name [Database Name] ,
        N'ALTER DATABASE [' + db.name
        + N'] SET PAGE_VERIFY CHECKSUM WITH NO_WAIT;' [Script]
FROM    sys.databases db
WHERE   db.state = 0
        AND db.is_read_only = 0
        AND db.page_verify_option != 2
        AND db.database_id > 4
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
UNION ALL
SELECT  'File Growth' [Type] ,
        db.name AS database_name ,
        N'ALTER DATABASE [' + db.name + N'] MODIFY FILE (NAME=[' + mf.name
        + N'], FILEGROWTH = ' + CASE mf.type_desc
                                  WHEN 'LOG' THEN '128MB'
                                  ELSE '256MB'
                                END + ');'
FROM    sys.master_files mf 
        INNER JOIN sys.databases db ON mf.database_id = db.database_id
WHERE   (is_percent_growth = 1 OR (is_percent_growth = 0 AND mf.growth = 128))
        AND db.state = 0
        AND db.is_read_only = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
UNION ALL
SELECT  'AUTO SHRINK' [Type] ,
        db.name ,
        N'ALTER DATABASE ' + QUOTENAME(name)
        + ' SET AUTO_SHRINK OFF WITH NO_WAIT;' AS [ToExecute]
FROM    sys.databases db
WHERE   db.state = 0
        AND db.is_read_only = 0
        AND is_auto_shrink_on = 1
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
UNION ALL
SELECT  'CURSOR_DEFAULT' [Type] ,
        db.name ,
        N'ALTER DATABASE ' + QUOTENAME(name)
        + ' SET CURSOR_DEFAULT  LOCAL WITH NO_WAIT;' AS [ToExecute]
FROM    sys.databases db
WHERE   db.state = 0
        AND db.is_read_only = 0
        AND is_local_cursor_default = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
UNION ALL
SELECT  'Auto Create Statistics' [Type] ,
        db.name ,
        N'ALTER DATABASE ' + QUOTENAME(name)
        + ' SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT;' AS [ToExecute]
FROM    sys.databases db
WHERE   db.state = 0
        AND db.is_read_only = 0
        AND is_auto_create_stats_on = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
        AND db.name NOT IN ( SELECT DatabaseName FROM @DB_Exclude )
UNION ALL
SELECT  'Auto Create Statistics' [Type] ,
        db.name ,
        N'ALTER DATABASE ' + QUOTENAME(name)
        + ' SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT;' AS [ToExecute]
FROM    sys.databases db
WHERE   db.state = 0
        AND db.is_read_only = 0
        AND is_auto_create_stats_on = 1
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
        AND db.name IN ( SELECT DatabaseName
                         FROM   @DB_Exclude )
UNION ALL
SELECT  'Auto Updtae Statistics' [Type] ,
        db.name ,
        N'ALTER DATABASE ' + QUOTENAME(name)
        + ' SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT;' AS [ToExecute]
FROM    sys.databases db
WHERE   db.state = 0
        AND db.is_read_only = 0
        AND is_auto_update_stats_on = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
        AND db.name NOT IN ( SELECT DatabaseName
                             FROM   @DB_Exclude )
UNION ALL
SELECT  'Auto Updtae Statistics' [Type] ,
        db.name ,
        N'ALTER DATABASE ' + QUOTENAME(name)
        + ' SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT;' AS [ToExecute]
FROM    sys.databases db
WHERE   db.state = 0
        AND db.is_read_only = 0
        AND is_auto_update_stats_on = 1
		AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeDB X WHERE X.name = db.name)
        AND db.name IN ( SELECT DatabaseName
                         FROM   @DB_Exclude )
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',1;
reconfigure'
FROM    sys.configurations
WHERE   name = 'show advanced options'
        AND value = 0
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',1;
reconfigure'
FROM    sys.configurations
WHERE   name = 'backup compression default'
        AND value = 0
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',1;
reconfigure'
FROM    sys.configurations
WHERE   name = 'optimize for ad hoc workloads'
        AND value = 0
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',1;
reconfigure'
FROM    sys.configurations
WHERE   name = 'Database Mail XPs'
        AND value = 0
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',50;
reconfigure'
FROM    sys.configurations
WHERE   name = 'cost threshold for parallelism'
        AND value = 5
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',0;
reconfigure'
FROM    sys.configurations
WHERE   name = 'max degree of parallelism'
        AND value != 0
        AND NOT EXISTS ( SELECT DatabaseName
                         FROM   @DB_Exclude )
        AND @IsCRMDynamicsON = 0
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',1;
reconfigure'
FROM    sys.configurations
WHERE   name = 'max degree of parallelism'
        AND value != 1
        AND ( EXISTS ( SELECT   DatabaseName
                       FROM     @DB_Exclude )
              OR @IsCRMDynamicsON = 1
            )
UNION ALL
SELECT  'Configuration' [Type] ,
        @@SERVERNAME ,
        'exec sp_configure ''' + name + ''',1;
reconfigure'
FROM    sys.configurations
WHERE   name = 'remote admin connections'
        AND value = 0
UNION ALL
SELECT  'Jobs' ,
        @@SERVERNAME ,
        'EXEC msdb.dbo.sp_update_job @job_id=N'''
        + CONVERT(NVARCHAR(36), job_id) + ''',@owner_login_name=N''sa'''
FROM    msdb..sysjobs
WHERE   owner_sid != 0x01
UNION ALL
SELECT  'SQL Error Log' ,
        @@SERVERNAME ,
        'USE [master]
GO
EXEC xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', N''Software\\Microsoft\\MSSQLServer\\MSSQLServer'', N''NumErrorLogs'', REG_DWORD, 30'
WHERE EXISTS ( SELECT TOP 1 1 FROM #SR_reg WHERE keyname = 'Number Error Logs' AND CurrentInstance = 1 AND value < 30 ) OR NOT EXISTS ( SELECT TOP 1 1 FROM #SR_reg WHERE keyname = 'Number Error Logs' AND CurrentInstance = 1)
UNION ALL
SELECT  'SQL Error Log' ,
        @@SERVERNAME ,
        'BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [DBA]    Script Date: 26/07/2016 12:44:04 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N''DBA'' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N''JOB'', @type=N''LOCAL'', @name=N''DBA''
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N''_Admin_ :: CycleErrorLog'', 
             @enabled=1, 
             @notify_level_eventlog=0, 
             @notify_level_email=0, 
             @notify_level_netsend=0, 
             @notify_level_page=0, 
             @delete_level=0, 
             @description=N''sp_cycle_errorlog.'', 
             @category_name=N''DBA'', 
             @owner_login_name=N''sa'', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [CycleErrorLog]    Script Date: 26/07/2016 12:44:04 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''CycleErrorLog'', 
             @step_id=1, 
             @cmdexec_success_code=0, 
             @on_success_action=1, 
             @on_success_step_id=0, 
             @on_fail_action=2, 
             @on_fail_step_id=0, 
             @retry_attempts=0, 
             @retry_interval=0, 
             @os_run_priority=0, @subsystem=N''TSQL'', 
             @command=N''EXEC sp_cycle_errorlog;'', 
             @database_name=N''master'', 
             @flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N''MidNight'', 
             @enabled=1, 
             @freq_type=4, 
             @freq_interval=1, 
             @freq_subday_type=1, 
             @freq_subday_interval=0, 
             @freq_relative_interval=0, 
             @freq_recurrence_factor=0, 
             @active_start_date=20140331, 
             @active_end_date=99991231, 
             @active_start_time=1, 
             @active_end_time=235959, 
             @schedule_uid=N''994a993a-227f-463f-9742-f2cba8623403''
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N''(local)''
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:'
WHERE   NOT EXISTS ( SELECT TOP 1 1 FROM msdb.[dbo].[sysjobs] WHERE [name] = N'_Admin_ :: CycleErrorLog' )
        AND (EXISTS ( SELECT TOP 1 1 FROM #SR_reg WHERE keyname = 'Number Error Logs' AND CurrentInstance = 1 AND value < 30 ) OR NOT EXISTS ( SELECT TOP 1 1 FROM #SR_reg WHERE keyname = 'Number Error Logs' AND CurrentInstance = 1))

UNION ALL
SELECT  'Windows Power Plan' ,
        @@SERVERNAME ,
        'USE [master]
GO
EXEC xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', N''SYSTEM\\ControlSet001\\Control\\Power\\User\\PowerSchemes'', N''ActivePowerScheme'', REG_SZ, ''8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c''' Script
WHERE   EXISTS ( SELECT TOP 1
                        1
                 FROM   #SR_reg
                 WHERE  CurrentInstance = 1
                        AND keyname = 'Power Plan'
                        AND value != 'High performance' )
UNION ALL
SELECT  'Performance' ,
        'tempdb' ,
        CASE WHEN mf.database_id IS NULL
             THEN 'USE [master]
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdev'
                  + CONVERT(VARCHAR(3), Num.n) + ''', FILENAME = N'''
                  + FileName + ''' , SIZE = ' + maxS.size + ' , FILEGROWTH = '
                  + f1.growth + ' )
GO'          WHEN MakeSameSize.Script IS NOT NULL THEN MakeSameSize.Script
             ELSE NULL
        END
FROM    ( SELECT    1 n
          UNION ALL
          SELECT    2 n
          UNION ALL
          SELECT    3 n
          UNION ALL
          SELECT    4 n
          UNION ALL
          SELECT    5 n
          UNION ALL
          SELECT    6 n
          UNION ALL
          SELECT    7 n
          UNION ALL
          SELECT    8 n
        ) Num
        CROSS APPLY ( SELECT TOP 1
                                LEFT(physical_name,
                                     LEN(physical_name) - CHARINDEX('\',
                                                              REVERSE(physical_name),
                                                              1) + 1)
                                + REPLACE(REVERSE(LEFT(REVERSE(physical_name),
                                                       CHARINDEX('\',
                                                              REVERSE(physical_name),
                                                              1) - 1)), '.mdf',
                                          CONVERT(VARCHAR(3), Num.n) + '.ndf') FileName ,
                                name ,
                                physical_name ,
                                size ,
                                CASE WHEN is_percent_growth = 0
                                     THEN CONVERT(VARCHAR(50), growth * 8)
                                          + 'KB'
                                     ELSE '256MB'
                                END growth
                      FROM      sys.master_files imf
                      WHERE     database_id = 2
                                AND file_id = 1
                    ) f1
        CROSS APPLY ( SELECT    CONVERT(VARCHAR(50), MAX(size * 8 / 1024))
                                + 'MB' size ,
                                MAX(size) OriginalSize
                      FROM      sys.master_files imf
                      WHERE     database_id = 2
                                AND imf.type = 0
                    ) maxS
        LEFT JOIN sys.master_files mf ON CASE WHEN mf.file_id > 1
                                              THEN mf.file_id - 1
                                              ELSE 1
                                         END = Num.n
                                         AND database_id = 2
                                         AND type = 0
        OUTER APPLY ( SELECT TOP 1
                                'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'''
                                + mf.name + ''', SIZE = ' + maxS.size + ');' Script
                      WHERE     maxS.OriginalSize != mf.size
                    ) MakeSameSize
WHERE   Num.n <= ( SELECT   CASE WHEN cpu_count > 8 THEN 8
                                 ELSE cpu_count
                            END
                   FROM     sys.dm_os_sys_info
                 )
        AND ( mf.database_id IS NULL
              OR MakeSameSize.Script IS NOT NULL
            )
UNION ALL
SELECT  *
FROM    #dm_server_registry
UNION ALL
SELECT  'TraceFlag' ,
        @@SERVERNAME ,
        Script
FROM    ( SELECT    1117 TraceFlag ,
                    'DBCC TRACEON (1117, -1); ' Script WHERE @MajorVersion < 1300 --SQL Server 2016
          UNION ALL
          SELECT    1118 ,
                    'DBCC TRACEON (1118, -1); ' Script WHERE @MajorVersion < 1300 --SQL Server 2016
          UNION ALL
          SELECT    1222 ,
                    'DBCC TRACEON (1222, -1); ' Script WHERE @MajorVersion < 1300 --SQL Server 2016
          UNION ALL
          SELECT    3226 ,
                    'DBCC TRACEON (3226, -1); ' Script WHERE @MajorVersion < 1300 --SQL Server 2016
        ) M
        LEFT JOIN #TraceFlag TF ON TF.TraceFlag = M.TraceFlag
WHERE   TF.TraceFlag IS NULL
UNION ALL
SELECT  Type ,
        DatabaseName ,
        Script
FROM    @SharePointAG
UNION ALL 
SELECT	'Secondary FileGroup' ,
        db.name ,'USE ' + QUOTENAME(db.name)+ '
GO
IF NOT EXISTS (SELECT TOP 1 1 FROM sys.filegroups WHERE [name] = N''SECONDARY'')
	ALTER DATABASE ' + QUOTENAME(db.name)+ ' ADD FILEGROUP [SECONDARY];
GO' 
FROM	sys.databases db
		CROSS APPLY (SELECT COUNT(DISTINCT mf.data_space_id)[NumberOfFileGroups] FROM sys.master_files mf WHERE mf.database_id = db.database_id AND mf.[type] = 0)ds
WHERE	db.database_id > 4
		AND [ds].[NumberOfFileGroups] = 1
UNION ALL 
SELECT	'2 Files Secondary FileGroup' ,
        db.name ,'USE [master]
GO
ALTER DATABASE ' + QUOTENAME(db.name)+ ' ADD FILE ( NAME = N''' + REPLACE(f1.[name],'<##>',CONVERT(VARCHAR(3), v.Number)) 
                  + ''', FILENAME = N'''
                  + REPLACE(f1.[FileName],'<##>',CONVERT(VARCHAR(3), v.Number)) + ''' , SIZE = ' + f1.size + ' , FILEGROWTH = '
                  + f1.growth + ' ) TO FILEGROUP [SECONDARY]
GO'		
FROM	sys.databases db
		INNER JOIN [master]..spt_values v ON v.[Type] = 'P' 
		CROSS APPLY (SELECT COUNT(1)[NumberOfFiles] FROM sys.master_files mf WHERE mf.database_id = db.database_id AND mf.[type] = 0)fn
		CROSS APPLY ( SELECT TOP 1
                                LEFT(physical_name,
                                     LEN(physical_name) - CHARINDEX('\',
                                                              REVERSE(physical_name),
                                                              1) + 1)
                                + REPLACE(REVERSE(LEFT(REVERSE(physical_name),
                                                       CHARINDEX('\',
                                                              REVERSE(physical_name),
                                                              1) - 1)), '.mdf',
                                          '<##>.ndf') [FileName] ,
                                [name] + N'<##>' [name],
                                '102400KB' size ,
                                '262144KB' growth
                      FROM      sys.master_files imf
                      WHERE     database_id = db.database_id
                                AND file_id = 1
                    ) f1
WHERE	db.database_id > 4
		AND v.Number BETWEEN 2 AND 3
		AND fn.NumberOfFiles = 1
UNION ALL 

SELECT	'Default Filegroup' ,
        db.name ,'USE ' + QUOTENAME(db.name)+ '
GO
IF NOT EXISTS (SELECT TOP 1 1 FROM sys.filegroups WHERE is_default = 1 AND name = N''SECONDARY'') ALTER DATABASE ' + QUOTENAME(db.name)+ ' MODIFY FILEGROUP [SECONDARY] DEFAULT;' 
FROM	sys.databases db
		CROSS APPLY (SELECT COUNT(DISTINCT mf.data_space_id)[NumberOfFileGroups] FROM sys.master_files mf WHERE mf.database_id = db.database_id AND mf.[type] = 0)ds
WHERE	db.database_id > 4
		AND [ds].[NumberOfFileGroups] = 1
UNION ALL 

SELECT	'Best Practice' ,
        db.name ,'USE [master]
GO
ALTER DATABASE ' + QUOTENAME(db.name)+ ' SET RECOVERY SIMPLE WITH NO_WAIT;
GO' 
FROM	sys.databases db
WHERE	db.database_id = 3
		AND db.recovery_model = 1;
DROP TABLE #TraceFlag;
--select * from #SR_reg
