USE msdb;
GO

-- 1. Create SQL Agent Job
EXEC sp_add_job  
    @job_name = N'DatabaseBackupToBlob',  
    @enabled = 1,  
    @description = N'Daily full backup of database to Azure Blob using managed identity.',  
    @owner_login_name = N'sa';  -- Use appropriate login (SQL Agent service account or sysadmin)

-- 2. Add a Job Step (T-SQL backup command)
EXEC sp_add_jobstep  
    @job_name = N'DatabaseBackupToBlob',  
    @step_name = N'Backup to Azure Blob',  
    @subsystem = N'TSQL',  
    @command = N'
        BACKUP DATABASE [YourDatabaseName]
        TO URL = ''https://<storage-account>.blob.core.windows.net/<container-name>/YourDatabaseName_$(ESCAPE_SQUOTE(DATE)).bak''
        WITH CREDENTIAL = ''https://<storage-account>.blob.core.windows.net/<container-name>'',
             COMPRESSION, STATS = 10;
    ',  
    @retry_attempts = 1,  
    @retry_interval = 5;

-- 3. Add a Job Schedule (daily at 2 AM — adjust as needed)
EXEC sp_add_schedule  
    @schedule_name = N'DailyBackupSchedule',  
    @freq_type = 4,  -- Daily  
    @freq_interval = 1,  -- Every day  
    @active_start_time = 020000;  -- 2:00 AM

-- 4. Attach the schedule to the job
EXEC sp_attach_schedule  
    @job_name = N'DatabaseBackupToBlob',  
    @schedule_name = N'DailyBackupSchedule';

-- 5. Add job to the SQL Agent (if needed)
EXEC sp_add_jobserver  
    @job_name = N'DatabaseBackupToBlob';
