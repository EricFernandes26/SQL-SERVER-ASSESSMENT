@echo off

rem Define o diretório de instalação do Python
set PYTHON_INSTALL_DIR=C:\Users\Administrator\AppData\Local\Programs\Python\Python312

rem Define o URL do instalador do Python 3.12.0
set PYTHON_INSTALLER_URL=https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe

rem Cria o diretório de instalação
mkdir %PYTHON_INSTALL_DIR%

rem Baixa o instalador do Python
curl -o python_installer.exe %PYTHON_INSTALLER_URL%

rem Instala o Python
python_installer.exe /quiet InstallAllUsers=1 PrependPath=1 TargetDir=%PYTHON_INSTALL_DIR%

rem Remove o instalador após a instalação
del python_installer.exe

echo Python 3.12.0 foi instalado com sucesso em %PYTHON_INSTALL_DIR%\python.exe!
