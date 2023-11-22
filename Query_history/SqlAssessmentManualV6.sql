--SAM-SQL06
-- Configurações iniciais
SET NOCOUNT ON;

-- Declaração de variáveis
DECLARE 
    @totaliops DECIMAL,
    @Throughput DECIMAL,
    @TotalMemKB DECIMAL,
    @Percentil95_SQLProcessUtilization FLOAT,
    @Percentil95_AvaiMemKB INT,
    @Normalized_CPU FLOAT,
    @Normalized_Mem FLOAT,
    @CombinedScore FLOAT,
    @Media_SQLProcessUtilization DECIMAL,
    @Media_AvaiMemKB DECIMAL,
    @InstanceType NVARCHAR(50);

-- Parte 1: Obter total de memória física
SELECT @TotalMemKB = (sm.total_physical_memory_kb / 1024)
FROM sys.dm_os_sys_info si, sys.dm_os_sys_memory sm;

-- Calcular IOPS e Throughput
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
SELECT @Media_SQLProcessUtilization = AVG(SQLProcessUtilization) FROM #TempResults;

-- Calcular a média da coluna AvaiMemKB
SELECT @Media_AvaiMemKB = AVG(AvaiMemKB) FROM #TempResults;

-- Normalizar as métricas para ficarem entre 0 e 100
SET @Normalized_CPU = (@Percentil95_SQLProcessUtilization / 100.0) * 50.0; -- Peso 50%
SET @Normalized_Mem = (@Percentil95_AvaiMemKB / 102400.0) * 50.0; -- Peso 50%

-- Calcular a pontuação combinada (pesos ajustáveis conforme necessário)
SET @CombinedScore = @Normalized_CPU + @Normalized_Mem;

-- Definir @InstanceType com base na pontuação combinada
SET @InstanceType = 
    CASE
        WHEN @CombinedScore BETWEEN 0 AND 10 THEN 't3.nano'
        WHEN @CombinedScore BETWEEN 11 AND 19 THEN 't3.medium'
        WHEN @CombinedScore BETWEEN 20 AND 29 THEN 't3.large'
        WHEN @CombinedScore BETWEEN 30 AND 39 THEN 'm5.large'
        WHEN @CombinedScore BETWEEN 40 AND 49 THEN 'm5.xlarge'
        WHEN @CombinedScore BETWEEN 50 AND 59 THEN 'm5.2xlarge'
        WHEN @CombinedScore BETWEEN 60 AND 69 THEN 'm5.2xlarge'
        WHEN @CombinedScore BETWEEN 70 AND 79 THEN 'r6i.8xlarge'
        WHEN @CombinedScore BETWEEN 80 AND 89 THEN 'r6i.12xlarge'
        WHEN @CombinedScore BETWEEN 90 AND 99 THEN 'r6i.16xlarge'
        WHEN @CombinedScore >= 100 THEN 'x2iedn.32xlarge'
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
    @Media_SQLProcessUtilization AS Media_SQLProcessUtilization,  
    MAX(Percentil95_AvaiMemKB) OVER (PARTITION BY HostName) AS Percentil95_AvaiMemKB,
    AVG(AvaiMemKB) OVER (PARTITION BY HostName) AS Media_AvaiMemKB,
    @InstanceType AS InstanceType, 
    [Event Time]
FROM #TempResults
WHERE [Event Time] >= DATEADD(MINUTE, -1, GETDATE());

-- Drop a tabela temporária
DROP TABLE #TempResults;
