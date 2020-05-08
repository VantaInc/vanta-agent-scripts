@echo off
:: check to make sure that both AGENT_KEY and OWNER_EMAIL are specified
IF "%~1"=="" goto :needparams
IF "%~2"=="" goto :needparams
IF NOT "%~3"=="" goto :needparams

:: download Vanta
curl -o vanta-installer.exe https://vanta-agent.s3.amazonaws.com/v1.5.0/vanta-installer.exe

:: write config files
mkdir C:\ProgramData\Vanta

:: set permissions on config files so installer doesn't overwrite
icacls C:\ProgramData\Vanta\vanta.conf /inheritance:r
icacls C:\ProgramData\Vanta\vanta.conf /grant "everyone":R

:: install vanta
vanta-installer.exe /S
echo {"AGENT_KEY": "%1", "NEEDS_OWNER": true, "OWNER_EMAIL": "%2"} > C:\ProgramData\Vanta\vanta.conf
C:\ProgramData\Vanta\vanta-cli reset

EXIT

:needparams
echo Usage: "install-vanta.bat [AGENT_KEY] [OWNER_EMAIL]"
exit /B 1
