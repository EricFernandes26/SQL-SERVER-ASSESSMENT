# Obter informações sobre a CPU
$cpuInfo = Get-WmiObject Win32_Processor
$cpuName = $cpuInfo.Name

# Obter informações sobre discos lógicos
$diskInfo = Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, `
    @{Name="Size (GB)";Expression={"{0:N2}" -f ($_.Size / 1GB)}}, `
    @{Name="FreeSpace (GB)";Expression={"{0:N2}" -f ($_.FreeSpace / 1GB)}}, `
    @{Name="FreeSpacePercentage";Expression={"{0:N2}" -f ($_.FreeSpace / $_.Size * 100)}}

# Caminho para o arquivo CSV
$csvPath = "C:\Users\Administrator\Desktop\SQL-SERVER-ASSESSMENT\results\info_discos.csv"

# Criar um objeto contendo as informações da CPU e dos discos
$result = New-Object PSObject -Property @{
    'CPU Name' = $cpuName
    'DeviceID' = $diskInfo.DeviceID
    'VolumeName' = $diskInfo.VolumeName
    'Size (GB)' = $diskInfo.'Size (GB)'
    'FreeSpace (GB)' = $diskInfo.'FreeSpace (GB)'
    'FreeSpacePercentage' = $diskInfo.FreeSpacePercentage
}

# Exportar para CSV com delimitador ;
$result | Export-Csv -Path $csvPath -NoTypeInformation -Delimiter ';'
