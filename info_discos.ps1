# Obter informações sobre a CPU
$cpuInfo = Get-WmiObject Win32_Processor
$cpuName = $cpuInfo.Name

# Obter informações sobre discos lógicos
$diskInfo = Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, `
    @{Name="Size (GB)";Expression={"{0:N2}" -f ($_.Size / 1GB)}}, `
    @{Name="FreeSpace (GB)";Expression={"{0:N2}" -f ($_.FreeSpace / 1GB)}}, `
    @{Name="FreeSpacePercentage";Expression={"{0:N2}" -f ($_.FreeSpace / $_.Size * 100)}}

# Coleta métricas de desempenho para discos físicos
$counterPaths = @(
    '\PhysicalDisk(_Total)\Disk Reads/sec',
    '\PhysicalDisk(_Total)\Disk Writes/sec',
    '\PhysicalDisk(_Total)\Disk Bytes/sec'
)

$performanceMetrics = Get-Counter -Counter $counterPaths

# Caminho para o arquivo CSV
$csvPath = "C:\Users\Administrator\Desktop\SQL-SERVER-ASSESSMENT\results\info_discos.csv"

# Criar um objeto contendo as informações da CPU, dos discos e das métricas de desempenho
$result = New-Object PSObject -Property @{
    'VolumeName' = $diskInfo.VolumeName
    'DeviceID' = $diskInfo.DeviceID
    'Size (GB)' = $diskInfo.'Size (GB)'
    'FreeSpace (GB)' = $diskInfo.'FreeSpace (GB)'
    'FreeSpacePercentage' = $diskInfo.FreeSpacePercentage
    'Throughput (MB/sec)' = $([math]::Round($performanceMetrics.CounterSamples[2].CookedValue / 1024 / 1024, 2))
    'IOPS (Writes/sec)' = $([math]::Round($performanceMetrics.CounterSamples[1].CookedValue / 1024, 2))
    'IOPS (Reads/sec)' = $([math]::Round($performanceMetrics.CounterSamples[0].CookedValue / 1024, 2))
}

# Exportar para CSV com delimitador ;
$result | Select-Object VolumeName, DeviceID, 'Size (GB)', 'FreeSpace (GB)', FreeSpacePercentage, 'Throughput (MB/sec)', 'IOPS (Writes/sec)', 'IOPS (Reads/sec)' | Export-Csv -Path $csvPath -NoTypeInformation -Delimiter ';'

