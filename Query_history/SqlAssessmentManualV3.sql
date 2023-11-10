DECLARE @totaliops DECIMAL;
DECLARE @Throughput DECIMAL;


SELECT 
    @totaliops = ISNULL(SUM(io_stall / NULLIF((num_of_reads + num_of_writes), 0)), 0),
    @Throughput = ISNULL(SUM((num_of_bytes_read + num_of_bytes_written) / 1048576), 0)
FROM sys.dm_io_virtual_file_stats(NULL, NULL);


SELECT 
    HostName,
    NumberOfCPUs AS NumberOfCPU,
    SQLProcessUtilization,
    [System Idle Process] AS [System Idle Process],
    [Other Process CPU Utilization],
    TotalMemKB,
    AvaiMemKB,
    PLE,
    @totaliops AS TotalIOPS,
    @Throughput AS Throughput,
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
        DATEADD(ms, -1 * ((SELECT cpu_ticks / (cpu_ticks / ms_ticks) FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) AS [Event Time]
    FROM (
        SELECT
            GETDATE() as collectionTime,
            (si.committed_kb / 1024) as Committed,
            (si.committed_target_kb / 1024) as targetCommited,
            (sm.total_physical_memory_kb / 1024) as totalMem,
            (sm.available_physical_memory_kb / 1024) as AvaiMem,
            (SELECT SUM(cntr_value) / COUNT(*) FROM sys.dm_os_performance_counters 
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
