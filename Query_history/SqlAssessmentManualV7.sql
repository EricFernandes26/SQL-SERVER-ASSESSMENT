--SAM-SQL07
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
    VCpu INT,
    Memory INT,
    Throughput INT,
    VCPUUtilization INT,
    MemoryUtilization INT,
    [Event Time] DATETIME
);

-- Calcular valores intermediários e inserir na tabela temporária
INSERT INTO #TempResults (HostName, NumberOfCPUs, SQLProcessUtilization, TotalMemKB, AvaiMemKB, PLE, Percentil95_SQLProcessUtilization, Percentil95_AvaiMemKB, [Event Time])
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
DECLARE @Media_AvaiMemKB DECIMAL;
SELECT @Media_AvaiMemKB = AVG(AvaiMemKB) FROM #TempResults;

-- Adicionar a lógica para definir @InstanceType
DECLARE @InstanceType NVARCHAR(50);

-- Lógica para sugerir valores
DECLARE @SuggestedVCPU INT,
        @SuggestedMemory INT,
        @SuggestedThroughput INT,
        @SuggestedVCPUUtilization INT,
        @SuggestedMemoryUtilization INT;

-- Lógica para sugerir valores de forma aleatória
SET @SuggestedVCPU = CAST(RAND() * (32 - 1) + 1 AS INT);  -- Intervalo de 1 a 32 VCPUs
SET @SuggestedMemory = CAST(RAND() * (65536 - 1024) + 1024 AS INT);  -- Intervalo de 1024 MB a 65,536 MB (64 GB)
SET @SuggestedThroughput = CAST(RAND() * (1000 - 1) + 1 AS INT);  -- Intervalo de 1 a 1000
SET @SuggestedVCPUUtilization = CAST(RAND() * (100 - 1) + 1 AS INT);  -- Intervalo de 1 a 100
SET @SuggestedMemoryUtilization = CAST(RAND() * (100 - 1) + 1 AS INT);  -- Intervalo de 1 a 100

-- Inserir os valores sugeridos na tabela temporária
UPDATE #TempResults
SET
    VCpu = @SuggestedVCPU,
    Memory = @SuggestedMemory,
    Throughput = @SuggestedThroughput,
    VCPUUtilization = @SuggestedVCPUUtilization,
    MemoryUtilization = @SuggestedMemoryUtilization;

-- Lógica para determinar a instância EC2
SELECT TOP 1
    @InstanceType = InstanceType
FROM
    (SELECT
        CASE
			WHEN @SuggestedVCPUUtilization >= 0 AND @SuggestedMemoryUtilization <=  10 THEN 't3.nano'
			WHEN @SuggestedVCPUUtilization >= 11 AND @SuggestedMemoryUtilization <= 19 THEN 't3.medium'
            WHEN @SuggestedVCPUUtilization >= 20 AND @SuggestedMemoryUtilization <= 29 THEN 'c6i.large'
            WHEN @SuggestedVCPUUtilization >= 30 AND @SuggestedMemoryUtilization <= 39 THEN 'm5.large'
			WHEN @SuggestedVCPUUtilization >= 40 AND @SuggestedMemoryUtilization <= 49 THEN 'm5.xlarge'
			WHEN @SuggestedVCPUUtilization >= 50 AND @SuggestedMemoryUtilization <= 59 THEN 'm5.2xlarge'
			WHEN @SuggestedVCPUUtilization >= 60 AND @SuggestedMemoryUtilization <= 69 THEN 'r6i.8xlarge'
			WHEN @SuggestedVCPUUtilization >= 70 AND @SuggestedMemoryUtilization <= 79 THEN 'r6i.12xlarge'
            WHEN @SuggestedVCPUUtilization >= 80 AND @SuggestedMemoryUtilization <= 89 THEN 'r6i.16xlarge'
			WHEN @SuggestedVCPUUtilization >= 90 AND @SuggestedMemoryUtilization <= 99 THEN 'x2iedn.32xlarge'
            ELSE 't3.micro'
        END AS InstanceType
    FROM
        #TempResults) AS SubQuery;

-- Consulta para obter resultados finais
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
WHERE [Event Time] >= DATEADD(MINUTE, -10, GETDATE());

-- Drop the temporary table
DROP TABLE #TempResults;
