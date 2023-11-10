DECLARE @totaliops DECIMAL;
DECLARE @Throughput DECIMAL;
DECLARE @TotalMemKB DECIMAL;

SELECT
    @TotalMemKB = (sm.total_physical_memory_kb / 1024)
FROM sys.dm_os_sys_info si, sys.dm_os_sys_memory sm;


SELECT 
    @totaliops = ISNULL(SUM(io_stall / NULLIF((num_of_reads + num_of_writes), 0)), 0),
    @Throughput = ISNULL(SUM((num_of_bytes_read + num_of_bytes_written) / 1048576), 0)
FROM sys.dm_io_virtual_file_stats(NULL, NULL);





-- Criar tabela temporária para armazenar os resultados intermediários
CREATE TABLE #TempResults (
    HostName NVARCHAR(128),
    NumberOfCPUs INT,
    SQLProcessUtilization INT,
    [System Idle Process] INT,
    [Other Process CPU Utilization] INT,
    TotalMemKB DECIMAL,
    AvaiMemKB DECIMAL,
    PLE DECIMAL,
    Percentil95_SQLProcessUtilization DECIMAL,
    Percentil95_AvaiMemKB DECIMAL,
    [Event Time] DATETIME
);

-- Calcular valores intermediários e inserir na tabela temporária
INSERT INTO #TempResults
SELECT 
    HOST_NAME() AS HostName,
    (SELECT cpu_count FROM sys.dm_os_sys_info) AS NumberOfCPUs,
    SQLProcessUtilization,
    SystemIdle AS [System Idle Process],
    100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization],
    PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY SQLProcessUtilization) OVER (PARTITION BY HOST_NAME()) AS Percentil95_SQLProcessUtilization,
    PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY x.AvaiMem) OVER (PARTITION BY HOST_NAME()) AS Percentil95_AvaiMemKB,
    @TotalMemKB AS TotalMemKB,
    x.AvaiMem AS AvaiMemKB,
    x.PLE,
    DATEADD(ms, -1 * ((SELECT cpu_ticks / (cpu_ticks / ms_ticks) FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) AS [Event Time]
FROM (
    SELECT
        GETDATE() AS collectionTime,
        (si.committed_kb / 1024) AS Committed,
        (si.committed_target_kb / 1024) AS targetCommited,
        (sm.total_physical_memory_kb / 1024) AS totalMem,
        (sm.available_physical_memory_kb / 1024) AS AvaiMem,
        (SELECT SUM(cntr_value) / COUNT(*) FROM sys.dm_os_performance_counters 
            WHERE counter_name = 'Page Life expectancy' AND object_name LIKE '%buffer node%') AS PLE
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
) AS y;

-- Selecionar resultados finais da tabela temporária
SELECT 
    HostName,
    NumberOfCPUs AS NumberOfCPU,
    SQLProcessUtilization,
    [System Idle Process] AS [System Idle Process],
    [Other Process CPU Utilization],
    TotalMemKB,
    AvaiMemKB,
    PLE,
    Percentil95_SQLProcessUtilization,
    Media_SQLProcessUtilization,
    Percentil95_AvaiMemKB,
    Media_AvaiMemKB,
    @totaliops AS TotalIOPS,
    @Throughput AS Throughput,
    [Event Time]
FROM (
    SELECT 
        HostName,
        NumberOfCPUs,
        SQLProcessUtilization,
        [System Idle Process],
        [Other Process CPU Utilization],
        TotalMemKB,
        AvaiMemKB,
        PLE,
        MAX(Percentil95_SQLProcessUtilization) OVER (PARTITION BY HostName) AS Percentil95_SQLProcessUtilization,
        AVG(SQLProcessUtilization) OVER (PARTITION BY HostName) AS Media_SQLProcessUtilization,
        MAX(Percentil95_AvaiMemKB) OVER (PARTITION BY HostName) AS Percentil95_AvaiMemKB,
        AVG(AvaiMemKB) OVER (PARTITION BY HostName) AS Media_AvaiMemKB,
        [Event Time],
        ROW_NUMBER() OVER (PARTITION BY HostName ORDER BY [Event Time] DESC) AS RowNum
    FROM #TempResults
    
) AS Result
WHERE [Event Time] >= DATEADD(MINUTE, -30, GETDATE())

-- Limpar a tabela temporária
DROP TABLE #TempResults;


