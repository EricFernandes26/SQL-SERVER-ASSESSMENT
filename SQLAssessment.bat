@echo off

rem Executa o script Python py-monitor.py
"C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe" "C:\Users\Administrator\Desktop\SQL-SERVER-ASSESSMENT\py-monitor.py"

rem Executa o script Python 95percentil.py
"C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe" "C:\Users\Administrator\Desktop\SQL-SERVER-ASSESSMENT\95percentil.py"

rem Executa o script PowerShell info_disco.ps1
powershell.exe -File "C:\Users\Administrator\Desktop\SQL-SERVER-ASSESSMENT\info_discos.ps1"

echo Scripts Python e PowerShell foram executados com sucesso!
