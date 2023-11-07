SELECT
    HOST_NAME() AS HostName,
    (SELECT cpu_count FROM sys.dm_os_sys_info) AS NumberOfCPUs,
    x.totalMem AS TotalMemKB,
    x.AvaiMem AS AvaiMemKB,
    x.PLE,
    y.Montagem,
    y.[Total (GB)],
    y.[Espaço Disponível (GB)],
    y.[Espaço Disponível (%)],
    y.[Espaço em uso (%)],
    x.collectionTime,
    @@Version AS DatabaseType
FROM
    (SELECT
        GETDATE() as collectionTime,
        (si.committed_kb/1024) as Committed,
        (si.committed_target_kb/1024) as targetCommited,
        (sm.total_physical_memory_kb/1024) as totalMem,
        (sm.available_physical_memory_kb/1024) as AvaiMem,
        (SELECT SUM(cntr_value)/COUNT(*) FROM sys.dm_os_performance_counters 
            WHERE counter_name = 'Page Life expectancy' AND object_name LIKE '%buffer node%') as PLE
    FROM sys.dm_os_sys_info si, sys.dm_os_sys_memory sm) as x
    CROSS APPLY (
        SELECT DISTINCT
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
    ) as y;
