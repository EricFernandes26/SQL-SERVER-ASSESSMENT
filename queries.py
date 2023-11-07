queries = {
    "sqlserver_assessment": """
      DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info); 

SELECT 
    HostName,
    NumberOfCPUs AS NumberOfCPU,
    SQLProcessUtilization,
    [System Idle Process] AS [System Idle Process],
    [Other Process CPU Utilization],
    TotalMemKB,
    AvaiMemKB,
    PLE,
    DatabaseType AS [Database Type],
    [Event Time]
FROM (
    SELECT 
        HOST_NAME() AS HostName,
        (SELECT cpu_count FROM sys.dm_os_sys_info) AS NumberOfCPUs,
        SQLProcessUtilization,
        SystemIdle AS [System Idle Process],
        100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization],
        x.totalMem AS TotalMemKB,
        x.AvaiMem AS AvaiMemKB,
        x.PLE,
        @@Version AS DatabaseType,
        DATEADD(ms, -1 * ((SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) AS [Event Time]
    FROM (
        SELECT
            GETDATE() as collectionTime,
            (si.committed_kb/1024) as Committed,
            (si.committed_target_kb/1024) as targetCommited,
            (sm.total_physical_memory_kb/1024) as totalMem,
            (sm.available_physical_memory_kb/1024) as AvaiMem,
            (SELECT SUM(cntr_value)/COUNT(*) FROM sys.dm_os_performance_counters 
                WHERE counter_name = 'Page Life expectancy' AND object_name LIKE '%buffer node%') as PLE
        FROM sys.dm_os_sys_info si, sys.dm_os_sys_memory sm
    ) AS x
    CROSS APPLY (
        SELECT TOP(30) 
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization, 
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle,
            [timestamp]
        FROM (
            SELECT [timestamp], CONVERT(xml, record) AS [record]
            FROM sys.dm_os_ring_buffers 
            WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
            AND record LIKE '%<SystemHealth>%'
        ) AS x
    ) AS y
) AS CombinedData
ORDER BY [Event Time] DESC;


        """,

   "sqlserver_assessment_Disk": """
SELECT
    y.Montagem,
    y.[Total (GB)],
    y.[Espaço Disponível (GB)],
    y.[Espaço Disponível (%)],
    y.[Espaço em uso (%)]
FROM
    (SELECT
        MF.database_id,
        MF.file_id,
        VS.volume_mount_point AS [Montagem],
        VS.logical_volume_name AS [Volume],
        CAST(CAST(VS.total_bytes AS DECIMAL(19, 2)) / 1024 / 1024 / 1024 AS DECIMAL(10, 2)) AS [Total (GB)],
        CAST(CAST(VS.available_bytes AS DECIMAL(19, 2)) / 1024 / 1024 / 1024 AS DECIMAL(10, 2)) AS [Espaço Disponível (GB)],
        CAST((CAST(VS.available_bytes AS DECIMAL(19, 2)) / CAST(VS.total_bytes AS DECIMAL(19, 2)) * 100) AS DECIMAL(10, 2)) AS [Espaço Disponível (%)],
        CAST((100 - CAST(VS.available_bytes AS DECIMAL(19, 2)) / CAST(VS.total_bytes AS DECIMAL(19, 2)) * 100) AS DECIMAL(10, 2)) AS [Espaço em uso (%)]
    FROM
        sys.master_files AS MF
        CROSS APPLY [sys].[dm_os_volume_stats](MF.database_id, MF.file_id) AS VS
    WHERE
        CAST(VS.available_bytes AS DECIMAL(19, 2)) / CAST(VS.total_bytes AS DECIMAL(19, 2)) * 100 < 100
    ) AS y;

    """ 

    #"SQLServerAssessement-Disk: """
       # query (colar consulta)

     #""" 

}
