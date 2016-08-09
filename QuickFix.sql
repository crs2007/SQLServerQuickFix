USE [master];
GO
/*
Biztalt:https://blogs.msdn.microsoft.com/blogdoezequiel/2009/01/25/sql-best-practices-for-biztalk/
Auto create statistics must be disabled
Auto update statistics must be disabled
MAXDOP (Max degree of parallelism) must be defined as 1 in both SQL Server 2000 and SQL Server 2005 in the instance in which BizTalkMsgBoxDB database exists
*/
DECLARE @DB_Exclude TABLE
(DatabaseName sysname)
--CRM Dynamics
INSERT @DB_Exclude
SELECT D.name
FROM   sys.databases D
WHERE  D.name IN ('MSCRM_CONFIG','OrganizationName_MSCRM');
DECLARE @IsCRMDynamicsON BIT = 0
SELECT TOP 1 @IsCRMDynamicsON = 1 
FROM   sys.server_principals SP
WHERE  SP.name = 'MSCRMSqlLogin'
IF @IsCRMDynamicsON = 0 
       SELECT TOP 1 @IsCRMDynamicsON = 1
   FROM   @DB_Exclude

--BizTalk
INSERT @DB_Exclude
SELECT D.name
FROM   sys.databases D
WHERE  D.name IN ('BizTalkMsgBoxDB','BizTalkRuleEngineDb','SSODB','BizTalkHWSDb','BizTalkEDIDb','BAMArchive','BAMStarSchema','BAMPrimaryImport','BizTalkMgmtDb','BizTalkAnalysisDb','BizTalkTPMDb');


INSERT @DB_Exclude
EXEC sp_MSforeachdb

'
use [?]
SELECT TOP 1 DB_NAME()[DatabaseName]
FROM   sys.database_principals DP
WHERE  DP.type = ''R''
              AND DP.name IN (''SPDataAccess'',''SPReadOnly'')'

             

IF OBJECT_ID('tempdb..#TraceFlag') IS NOT NULL DROP TABLE #TraceFlag
CREATE TABLE #TraceFlag(TraceFlag INT,Status INT,Global INT,Session INT)
INSERT #TraceFlag
exec('DBCC TRACESTATUS(-1)')
  
       DECLARE @ver nvarchar(128)
       DECLARE @key varchar(8000)
       DECLARE @ComptabilityLevel nvarchar(128)



  /* declare variables */
       DECLARE @InstanceNames nvarchar(100) = @@servicename
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
             IF OBJECT_ID('tempdb..#SR_reg') IS NOT NULL DROP TABLE #SR_reg
       CREATE TABLE #SR_reg
             (
                    Service VARCHAR(1000),
                    InstanceNames VARCHAR(1000),
                    keyname CHAR(200) ,
                    value VARCHAR(1000),
                    CurrentInstance AS CASE WHEN InstanceNames = @@SERVICENAME THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END
             );
       DECLARE @keyi VARCHAR(8000); -- Holds Registry Key Value
             
       DECLARE @SQLServiceNamei VARCHAR(8000);
       DECLARE @AgentServiceNamei VARCHAR(8000);

  
  --BEGIN
--Build Sql Server's full service name
        SET @SQLServiceNamei = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                                    THEN 'MSSQLSERVER'
                                    ELSE 'MSSQL$' + @InstanceNames
                                END; 

        SET @keyi = 'SYSTEM\CurrentControlSet\Services\' + @SQLServiceNamei;
             DELETE FROM @reg  
--MSSQLSERVER Service Account
        INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'ObjectName';
        UPDATE  @reg
        SET     keyname = @SQLServiceNamei; 
             INSERT #SR_reg
                     ( Service, InstanceNames,keyname, value )
             SELECT 'SQL Server Engine',@InstanceNames,'Account Name'  ,value FROM @reg;
             
             
             -------------------------------------------------------------------------------
             IF @InstanceNames = @@SERVICENAME
             BEGIN
                 SET @ver = CAST(serverproperty('ProductVersion') AS nvarchar)
                    IF ( SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1) = '10' )
                    BEGIN
                           IF SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)),1,CHARINDEX('.', SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)))-1) = '50'
                                 SELECT @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1) + '_' + SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)),1,CHARINDEX('.', SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)))-1);
                           ELSE SELECT @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
                    END
   
                    ELSE SELECT @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
             END
                    
             SET @keyi = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                                    THEN 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\MSSQLServer\CurrentVersion'
                                    ELSE 'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\' + @InstanceNames + '\MSSQLServer\CurrentVersion'
                                END; 
             DELETE FROM @reg;
             DELETE FROM @Tempreg; 
        INSERT  INTO @Tempreg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'CurrentVersion';
                    
             SELECT @ver = value
         FROM   @Tempreg;
             SET @ComptabilityLevel = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1) + SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver)+1,LEN(@ver) ), 1, 1);
             IF ( SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1) = '10' )
             BEGIN
                    IF SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)),1,CHARINDEX('.', SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)))-1) = '50'
                           SELECT @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1) + '_' + SUBSTRING(SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)),1,CHARINDEX('.', SUBSTRING(@ver, CHARINDEX('.', @ver)+1 , LEN(@ver)))-1);
                    ELSE SELECT @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
             END
   
             ELSE SELECT @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
----------------------------------------------------------------------------------------------------------------------------------
             SET @key = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\Setup'
                    INSERT   @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'PatchLevel';
                    
             INSERT #SR_reg ( Service,InstanceNames, keyname, value )
             SELECT 'SQL Server Engine Version',@InstanceNames,'Last Version Installed' ,value FROM @reg;
                    
             
----------------------------------------------------------------------------------------------------------------------------------
             DELETE FROM @reg;
             SET @keyi = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\Setup'
             INSERT  INTO @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'Edition';
             INSERT #SR_reg ( Service,InstanceNames, keyname, value )
             SELECT 'SQL Server Engine Edition',@InstanceNames,'Edition Installed' ,value FROM @reg;
                    
             
----------------------------------------------------------------------------------------------------------------------------------
             --Error Log file
             DELETE FROM @reg;
        SET @keyi = N'Software\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\MSSQLServer'
             INSERT  INTO @reg
        EXECUTE xp_regread N'HKEY_LOCAL_MACHINE',@keyi, N'NumErrorLogs';
             INSERT #SR_reg ( Service,InstanceNames, keyname, value )
             SELECT 'SQL Server Number of Error Log files',@InstanceNames,'Number Error Logs' ,value FROM @reg;     
                     
                      
----------------------------------------------------------------------------------------------------------------------------------
             DELETE FROM @reg;
             SET @key = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @ComptabilityLevel;
        INSERT  INTO @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'CustomerFeedback';
             INSERT #SR_reg ( Service,InstanceNames, keyname, value )
             SELECT 'SQL Server Customer Feedback',@InstanceNames,'Customer Feedback Enabled' ,value FROM @reg;
             DELETE FROM @reg;
        INSERT  INTO @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'EnableErrorReporting';
             INSERT #SR_reg ( Service,InstanceNames, keyname, value )
             SELECT 'SQL Server Error Reporting',@InstanceNames,'Error Reporting Enabled' ,value FROM @reg;
                    
             
----------------------------------------------------------------------------------------------------------------------------------
        --SQLSERVERAGENT Service Account
        SET @AgentServiceNamei = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                                        THEN 'SQLSERVERAGENT'
                                        ELSE 'SQLAgent$' + @InstanceNames
                                END; 
        SET @keyi = 'SYSTEM\CurrentControlSet\Services\' + @AgentServiceNamei; 
             
        DELETE FROM @reg  
        INSERT  INTO @reg
                EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'ObjectName';
       
        UPDATE  @reg
        SET     keyname = @AgentServiceNamei
        WHERE   keyname = 'ObjectName';
        INSERT #SR_reg
                ( Service, InstanceNames,keyname, value )
        SELECT 'SQL Server Agent',@InstanceNames,'Account Name' ,value FROM @reg;
-------------------------
        --Windows Power Plan
        SET @keyi = 'SYSTEM\ControlSet001\Control\Power\User\PowerSchemes'--'SOFTWARE\Microsoft\Windows\CurrentVersion\explorer\ControlPanel\NameSpace\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}'; 
             
        DELETE FROM @reg  
        INSERT  INTO @reg
                EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'ActivePowerScheme';--'PreferredPlan';
       
        INSERT #SR_reg
                ( Service, InstanceNames,keyname, value )
        SELECT 'Windows Power Plan',@InstanceNames,'Power Plan' ,CASE CONVERT(VARCHAR(50),value) 
                           WHEN '381b4222-f694-41f0-9685-ff5bb260df2e' THEN 'Balanced'
                           WHEN 'a1841308-3541-4fab-bc81-f71556f20b4a' THEN 'Power saver'
                           WHEN '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' THEN 'High performance'
                           ELSE NULL END 
         FROM   @reg;
             
-------------------------
        DELETE FROM @reg  
        
        SET @keyi = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                            THEN 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\MSSQLServer\Parameters'
                            ELSE 'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\' + @InstanceNames + '\MSSQLServer\Parameters'
                        END; 
        DELETE FROM @reg  
        INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs3';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs4';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs5';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs6';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs7';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs8';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs9';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs10';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs11';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs12';
             INSERT  INTO @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs13';
       
        UPDATE  @reg
        SET     keyname = @InstanceNames
        WHERE   keyname like 'SQLArgs%';
             
        INSERT #SR_reg
                ( Service, InstanceNames,keyname, value )
        SELECT 'SQL Server Trace Flage',@InstanceNames,'Trace Flage' ,value FROM @reg;
  --END
  
select 'PAGE VERIFY'[Type],db.name [Database Name],N'ALTER DATABASE [' + db.name + N'] SET PAGE_VERIFY CHECKSUM  WITH NO_WAIT;' [Script]
from sys.databases db
WHERE	db.state = 0
		and db.is_read_only = 0
		and db.page_verify_option != 2
		and db.database_id > 4
UNION ALL
SELECT 'File Growth'[Type],db.name as database_name,N'ALTER DATABASE [' + db.name + N'] MODIFY FILE (NAME=[' + mf.name + N'], FILEGROWTH = ' + CASE mf.type_desc WHEN 'LOG' THEN '128MB' ELSE '256MB' END + ');'
FROM   sys.master_files mf (NOLOCK)
       INNER JOIN sys.databases db (NOLOCK) on mf.database_id = db.database_id
WHERE  is_percent_growth=1
		AND db.state = 0
		AND db.is_read_only = 0
UNION ALL
SELECT  'AUTO SHRINK'[Type],db.name,N'ALTER DATABASE ' + QUOTENAME(name) + ' SET AUTO_SHRINK OFF WITH NO_WAIT;' AS [To Execute]
FROM    sys.databases db
WHERE	db.state = 0
		AND db.is_read_only = 0
		AND is_auto_shrink_on = 1
UNION ALL
SELECT  'CURSOR_DEFAULT'[Type],db.name,N'ALTER DATABASE ' + QUOTENAME(name) + ' SET CURSOR_DEFAULT  LOCAL WITH NO_WAIT;' AS [To Execute]
FROM    sys.databases db
WHERE	db.state = 0
and db.is_read_only = 0
AND is_local_cursor_default = 0
UNION ALL
SELECT  'Auto Create Statistics'[Type],db.name,N'ALTER DATABASE ' + QUOTENAME(name) + ' SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT;' AS [To Execute]
FROM    sys.databases db
WHERE	db.state = 0
		and db.is_read_only = 0
		AND is_auto_create_stats_on = 0
		AND db.name NOT IN(SELECT DatabaseName FROM    @DB_Exclude)
UNION ALL
SELECT  'Auto Create Statistics'[Type],db.name,N'ALTER DATABASE ' + QUOTENAME(name) + ' SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT;' AS [To Execute]
FROM    sys.databases db
WHERE	db.state = 0
		and db.is_read_only = 0
		AND is_auto_create_stats_on = 1
		AND db.name IN(SELECT DatabaseName FROM @DB_Exclude)
UNION ALL
SELECT  'Auto Updtae Statistics'[Type],db.name,N'ALTER DATABASE ' + QUOTENAME(name) + ' SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT;' AS [To Execute]
FROM    sys.databases db
WHERE	db.state = 0
		and db.is_read_only = 0
		AND is_auto_update_stats_on = 0
		AND db.name NOT IN(SELECT DatabaseName FROM    @DB_Exclude)
UNION ALL
SELECT  'Auto Updtae Statistics'[Type],db.name,N'ALTER DATABASE ' + QUOTENAME(name) + ' SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT;' AS [To Execute]
FROM    sys.databases db
WHERE	db.state = 0
		and db.is_read_only = 0
		AND is_auto_update_stats_on = 1
		AND db.name IN(SELECT DatabaseName FROM @DB_Exclude)
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',1;
reconfigure'
from	sys.configurations
WHERE	name = 'show advanced options'
		and value = 0
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',1;
reconfigure'
from	sys.configurations
WHERE	name = 'backup compression default'
		and value = 0
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',1;
reconfigure'
FROM	sys.configurations
WHERE	name = 'optimize for ad hoc workloads'
		and value = 0
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',1;
reconfigure'
FROM	sys.configurations
WHERE	name = 'Database Mail XPs'
		and value = 0
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',50;
reconfigure'
FROM	sys.configurations
WHERE	name = 'cost threshold for parallelism'
		and value = 5
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',0;
reconfigure'
FROM	sys.configurations
WHERE	name = 'max degree of parallelism'
		and value != 0
        AND NOT EXISTS (SELECT DatabaseName FROM @DB_Exclude)
        AND @IsCRMDynamicsON = 0
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',1;
reconfigure'
FROM	sys.configurations
WHERE	name = 'max degree of parallelism'
		and value != 1
        AND( EXISTS (SELECT DatabaseName FROM @DB_Exclude) OR @IsCRMDynamicsON = 1)
UNION ALL
select 'Configuration'[Type],@@SERVERNAME,'exec sp_configure ''' +  name + ''',1;
reconfigure'
FROM	sys.configurations
WHERE	name = 'remote admin connections'
		and value = 0
union all 
select 'Jobs' , @@SERVERNAME,'EXEC msdb.dbo.sp_update_job @job_id=N''' + CONVERT(nvarchar(36),job_id) + ''',@owner_login_name=N''sa'''
from   msdb..sysjobs
WHERE  owner_sid != 0x01
union all 
select 'SQL Error Log' , @@SERVERNAME,'USE [master]
GO
EXEC xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', N''Software\\Microsoft\\MSSQLServer\\MSSQLServer'', N''NumErrorLogs'', REG_DWORD, 30' WHERE exists (select top 1 1 from #SR_reg WHERE keyname = 'Number Error Logs' and CurrentInstance = 1 and value < 30)
union all 
select 'SQL Error Log' , @@SERVERNAME, 'BEGIN TRANSACTION
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
EndSave:' WHERE NOT EXISTS (SELECT TOP 1 1 FROM msdb.[dbo].[sysjobs] WHERE name = '_Admin_ :: CycleErrorLog') AND exists (select top 1 1 from #SR_reg WHERE keyname = 'Number Error Logs' and CurrentInstance = 1 and value < 30)
UNION ALL
select 'Windows Power Plan' , @@SERVERNAME,'USE [master]
GO
EXEC xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', N''SYSTEM\\ControlSet001\\Control\\Power\\User\\PowerSchemes'', N''ActivePowerScheme'', REG_SZ, ''8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c''' Script
WHERE EXISTS (SELECT TOP 1 1 FROM #SR_reg WHERE CurrentInstance = 1 AND keyname = 'Power Plan' AND value != 'High performance')
UNION ALL
select 'tempdb' , @@SERVERNAME,case when mf.database_id is null then    'USE [master]
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdev' + convert(varchar(3),Num.n) + ''', FILENAME = N''' + FileName + ''' , SIZE = ' + maxS.size + ' , FILEGROWTH = ' + f1.growth + ' )
GO'
when MakeSameSize.Script is not null then MakeSameSize.Script
else null end
from   (select 1 n
union all
select 2 n
union all
select 3 n
union all
select 4 n
union all
select 5 n
union all
select 6 n
union all
select 7 n
union all
select 8 n)Num
cross apply (select top 1 LEFT(physical_name,LEN(physical_name) - charindex('\',reverse(physical_name),1) + 1) + REPLACE(REVERSE(LEFT(REVERSE(physical_name),CHARINDEX('\', REVERSE(physical_name), 1) - 1)),'.mdf',
                                        convert(varchar(3),Num.n) +'.ndf') FileName,
                                        name,
                                        physical_name,
                                        size,
                                        case when is_percent_growth = 0 then convert(varchar(50),growth * 8) +'KB' ELSE '%'END growth 
                FROM	sys.master_files imf 
					WHERE	database_id = 2 
							AND file_id = 1)f1
cross apply (select convert(varchar(50),max(size*8/1024))+'MB' size,max(size) OriginalSize from sys.master_files imf WHERE database_id = 2 AND imf.type = 0)maxS
left join sys.master_files mf on case when mf.file_id > 1 then mf.file_id - 1 else 1 end = Num.n
and database_id = 2
             and type = 0
outer apply(select top 1 'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''' + mf.name + ''', SIZE = '+ maxS.size + ');' Script WHERE maxS.OriginalSize!=mf.size)MakeSameSize
WHERE  Num.n <= (select case when cpu_count > 8 then 8 else cpu_count end from sys.dm_os_sys_info)
             and (mf.database_id is null or MakeSameSize.Script is not null)
union all 
SELECT 'TraceFlag' , @@SERVERNAME,'USE [master]
GO
EXEC xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', N''SOFTWARE\\Microsoft\Microsoft SQL Server\\MSSQL' + @ver + '.' + @InstanceNames + '\\MSSQLServer\\Parameters'', N''SQLArg' +CONVERT(VARCHAR(10),N.Num + ROW_NUMBER() OVER (ORDER BY N.Num)) + ''', REG_SZ, ''' + M.TraceFlag + '''' Script
FROM   (SELECT '-t1117' TraceFlag
UNION ALL SELECT '-t1118') M
             LEFT JOIN (
                                 select *
                             FROM sys.dm_server_registry WHERE registry_key = 'HKLM\Software\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\MSSQLServer\Parameters' and value_name like 'SQLArg%'
                                 and value_name not in ('SQLArg0','SQLArg1','SQLArg2')
                                 and convert(varchar(20),value_data) like '-t%') TF ON CONVERT(VARCHAR(50),TF.value_data) = M.TraceFlag
CROSS JOIN (select top 1 value_name,replace(value_name,'SQLArg','') Num from sys.dm_server_registry WHERE registry_key = 'HKLM\Software\Microsoft\Microsoft SQL Server\MSSQL' + @ver + '.' + @InstanceNames + '\MSSQLServer\Parameters' and value_name like 'SQLArg%' order by value_name desc) N
WHERE  TF.value_data IS NULL
union all 
SELECT 'TraceFlag' , @@SERVERNAME,Script
FROM   (SELECT 1117 TraceFlag,'DBCC TRACEON (1117, -1); ' Script
UNION ALL SELECT 1118,'DBCC TRACEON (1118, -1); ' Script) M
             LEFT JOIN #TraceFlag TF ON TF.TraceFlag = M.TraceFlag
WHERE  TF.TraceFlag IS NULL
DROP TABLE #TraceFlag
--select * from #SR_reg
