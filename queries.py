queries = {
    "sqlserver_assessment": """
        --SAM-SQL05
SET NOCOUNT ON;
DECLARE @totaliops DECIMAL;
DECLARE @Throughput DECIMAL;
DECLARE @TotalMemKB DECIMAL;

-- Parte 1: Obter total de memória física
SELECT @TotalMemKB = (sm.total_physical_memory_kb / 1024)
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
    @TotalMemKB AS TotalMemKB,
    x.AvaiMem AS AvaiMemKB,
    x.PLE,
    PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY SQLProcessUtilization) OVER (PARTITION BY HOST_NAME()) AS Percentil95_SQLProcessUtilization,
    PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY x.AvaiMem) OVER (PARTITION BY HOST_NAME()) AS Percentil95_AvaiMemKB,
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
        [timestamp],
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS AvaiMem
    FROM (
        SELECT [timestamp], CONVERT(xml, record) AS [record]
        FROM sys.dm_os_ring_buffers 
        WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
        AND record LIKE '%<SystemHealth>%'
    ) AS x
) AS y;

-- Calcular a média da coluna SQLProcessUtilization
DECLARE @Media_SQLProcessUtilization DECIMAL;
SELECT @Media_SQLProcessUtilization = AVG(SQLProcessUtilization) FROM #TempResults;

-- Calcular a média da coluna AvaiMemKB
DECLARE @Media_AvaiMemKB DECIMAL; -- Alterado para DECIMAL para garantir a comparação correta
SELECT @Media_AvaiMemKB = AVG(AvaiMemKB) FROM #TempResults;

-- Calcular o percentil 95 da coluna SQLProcessUtilization
--DECLARE @Percentil95_SQLProcessUtilization DECIMAL;
--SELECT @Percentil95_SQLProcessUtilization = PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY SQLProcessUtilization) OVER () FROM #TempResults;

-- Calcular o percentil 95 da coluna AvaiMemKB
--DECLARE @Percentil95_AvaiMemKB DECIMAL;
--SELECT @Percentil95_AvaiMemKB = PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY AvaiMemKB) OVER () FROM #TempResults;


-- Adicionar a lógica para definir @InstanceType
DECLARE @InstanceType NVARCHAR(50);
DECLARE @InstanceFamily NVARCHAR(50); 
DECLARE @Percentil95_SQLProcessUtilization FLOAT; 
DECLARE @Percentil95_AvaiMemKB INT;


SET @InstanceType = 
    CASE
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 0 AND 10 AND @Percentil95_AvaiMemKB BETWEEN 0 AND 10240 THEN 't3.nano'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 11 AND 19 AND @Percentil95_AvaiMemKB BETWEEN 10241 AND 20480 THEN 't3.medium'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 20 AND 29 AND @Percentil95_AvaiMemKB BETWEEN 20481 AND 30720 THEN 't3.large'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 30 AND 39 AND @Percentil95_AvaiMemKB BETWEEN 30721 AND 40960 THEN 'm5.large'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 40 AND 49 AND @Percentil95_AvaiMemKB BETWEEN 40961 AND 51200 THEN 'm5.xlarge'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 50 AND 59 AND @Percentil95_AvaiMemKB BETWEEN 51201 AND 61440 THEN 'm5.2xlarge'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 60 AND 69 AND @Percentil95_AvaiMemKB BETWEEN 61441 AND 71680 THEN 'm5.2xlarge'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 70 AND 79 AND @Percentil95_AvaiMemKB BETWEEN 71681 AND 81920 THEN 'r6i.8xlarge'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 80 AND 89 AND @Percentil95_AvaiMemKB BETWEEN 81921 AND 92160 THEN 'r6i.12xlarge'
        WHEN @Percentil95_SQLProcessUtilization BETWEEN 90 AND 99 AND @Percentil95_AvaiMemKB BETWEEN 92161 AND 102400 THEN 'r6i.16xlarge'
        WHEN @Percentil95_SQLProcessUtilization >= 100 OR @Percentil95_AvaiMemKB >= 102401 THEN 'x2iedn.32xlarge'
        ELSE 't3.small' -- Defina o tipo de instância padrão
    END;


-- Selecionar resultados finais da tabela temporária
SELECT 
    HostName,
    NumberOfCPUs AS NumberOfCPU,
    SQLProcessUtilization,
    TotalMemKB,
    AvaiMemKB,
    PLE,
	@totaliops AS TotalIOPS,
    @Throughput AS Throughput,
    Percentil95_SQLProcessUtilization,
	@Media_SQLProcessUtilization AS Media_SQLProcessUtilization,  -- Adicionar a coluna desejada aqui
    MAX(Percentil95_AvaiMemKB) OVER (PARTITION BY HostName) AS Percentil95_AvaiMemKB,
    AVG(AvaiMemKB) OVER (PARTITION BY HostName) AS Media_AvaiMemKB,
	@InstanceType AS InstanceType, -- Adicionar a coluna desejada aqui
    [Event Time]
FROM #TempResults
WHERE [Event Time] >= DATEADD(SECOND, -160, GETDATE())


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

    
}
