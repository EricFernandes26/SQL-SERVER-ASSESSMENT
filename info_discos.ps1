# Obter informações sobre discos lógicos
$diskInfo = Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, `
    @{Name="Size (GB)";Expression={"{0:N2}" -f ($_.Size / 1GB)}}, `
    @{Name="FreeSpace (GB)";Expression={"{0:N2}" -f ($_.FreeSpace / 1GB)}}, `
    @{Name="FreeSpacePercentage";Expression={"{0:N2}" -f ($_.FreeSpace / $_.Size * 100)}}

# Caminho para o arquivo CSV
$csvPath = "C:\Users\Administrator\Desktop\SQL-SERVER-ASSESSMENT\results\info_discos.csv"

# Exportar para CSV com delimitador ;
$diskInfo | Export-Csv -Path $csvPath -NoTypeInformation -Delimiter ';'

