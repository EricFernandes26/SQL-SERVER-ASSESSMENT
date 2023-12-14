queries = {
    "sqlserver_assessment": """
SELECT 
    HOST_NAME() AS HostName,
    DB_NAME(mf.database_id) AS DatabaseName,
    CONVERT(DECIMAL(10,2), SUM(mf.size) * 8 / 1024.0) AS TotalSizeMB,
    (SELECT cpu_count FROM sys.dm_os_sys_info) AS NumberOfCPUs,
    (SELECT SUM(cntr_value) / COUNT(*) 
     FROM sys.dm_os_performance_counters 
     WHERE counter_name = 'Page Life expectancy' AND object_name LIKE '%buffer node%'
    ) AS PLE,
    x.SQLProcessUtilization,
    FORMAT(physical_memory_kb / (1024.0 * 1024.0), 'N2') AS physical_memory_gb,
    CONVERT(INT, b.CostThreshold) AS [Cost Threshold for Parallelism],
    CONVERT(INT, b.MaxDegree) AS [Max Degree of Parallelism],
    c.name,
    CAST(c.value AS VARCHAR(255)) AS ConvertedValue
FROM sys.dm_os_sys_info
CROSS APPLY (
    SELECT name, value, [description]
    FROM sys.configurations
    WHERE name LIKE '%server memory%'
) c
CROSS APPLY (
    SELECT 
        MAX(CASE WHEN name = 'cost threshold for parallelism' THEN value END) AS CostThreshold,
        MAX(CASE WHEN name = 'max degree of parallelism' THEN value_in_use END) AS MaxDegree
    FROM sys.configurations
    WHERE name IN ('cost threshold for parallelism', 'max degree of parallelism')
) b
CROSS APPLY (
    SELECT TOP (1)
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization
    FROM (
        SELECT [timestamp], CONVERT(xml, record) AS [record]
        FROM sys.dm_os_ring_buffers 
        WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
          AND record LIKE '%<SystemHealth>%'
    ) AS xInner
    ORDER BY [timestamp] DESC
) x
JOIN sys.master_files mf ON mf.database_id > 4 -- Excluir bancos de dados do sistema
GROUP BY mf.database_id, c.name, c.value, c.[description], x.SQLProcessUtilization, b.CostThreshold, b.MaxDegree, physical_memory_kb
OPTION (RECOMPILE);



""",

"sqlserver_assessment_databases": """
--- query para ver o total de databases ativos e inativos 

SELECT 
    COUNT(*) AS TotalDatabases,
    SUM(CASE WHEN state_desc = 'ONLINE' THEN 1 ELSE 0 END) AS ActiveDatabases,
    SUM(CASE WHEN state_desc <> 'ONLINE' THEN 1 ELSE 0 END) AS InactiveDatabases
FROM sys.databases;
    """,

"sqlserver_assessment_CPU_Stats": """
WITH DB_CPU_Stats
AS
(
    SELECT DatabaseID, DB_Name(DatabaseID) AS [DatabaseName], 
      SUM(total_worker_time) AS [CPU_Time_Ms]
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY (
                    SELECT CONVERT(int, value) AS [DatabaseID] 
                  FROM sys.dm_exec_plan_attributes(qs.plan_handle)
                  WHERE attribute = N'dbid') AS F_DB
    GROUP BY DatabaseID
)
SELECT
    DatabaseName,
    [CPU_Time_Ms], 
    CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPUPercent]
FROM DB_CPU_Stats
--WHERE DatabaseID > 4 -- system databases
--AND DatabaseID <> 32767 -- ResourceDB
ORDER BY [CPU_Time_Ms] DESC OPTION (RECOMPILE);


    """,

"sqlserver_assessment_Memory_Stats": """

DECLARE @total_buffer INT;  
  
SELECT @total_buffer = cntr_value  
FROM sys.dm_os_performance_counters   
WHERE RTRIM([object_name]) LIKE '%Buffer Manager'  
AND counter_name = 'Database Pages';  
  
;WITH src AS  
(  
  SELECT   
    database_id, db_buffer_pages = COUNT_BIG(*)  
  FROM sys.dm_os_buffer_descriptors  
  --WHERE database_id BETWEEN 5 AND 32766  
  GROUP BY database_id  
)  
SELECT  
  [db_name] = CASE [database_id] WHEN 32767   
                THEN 'Resource DB'   
                ELSE DB_NAME([database_id]) END,  
  db_buffer_pages,  
  db_buffer_MB = db_buffer_pages / 128,  
  db_buffer_percent = CONVERT(DECIMAL(6,3),   
  db_buffer_pages * 100.0 / @total_buffer)  
FROM src  
WHERE [database_id] <> 32767  -- Excluir Resource DB
ORDER BY db_buffer_MB DESC;

    """,

"sqlserver_assessment_AlwaysOn_Mirror": """
--Consulta para verificar se os databases estao em alwaysOn, Mirror ou nenhum dos dois
SELECT
    d.name AS DatabaseName,
    CASE
        WHEN h.is_local = 1 THEN 'Always On'
        WHEN m.mirroring_state_desc = 'SYNCHRONIZED' THEN 'Mirroring'
        ELSE 'Nenhum dos dois'
    END AS Configuracao
FROM
    sys.databases d
LEFT JOIN
    sys.dm_hadr_database_replica_states h ON d.database_id = h.database_id AND h.is_local = 1
LEFT JOIN
    sys.database_mirroring m ON d.database_id = m.database_id
WHERE
    d.database_id > 4; -- Excluir bancos de sistema


    """,



"sqlserver_assessment_login": """
---Total de Conexões por Login:
SELECT 
    DB_NAME(dbid) as DBName, 
    COUNT(dbid) as NumberOfConnections,
    loginame as LoginName
FROM
    sys.sysprocesses
WHERE 
    dbid > 0
GROUP BY 
    dbid, loginame
;

    """



}
