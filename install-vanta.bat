:: check to make sure that both AGENT_KEY and OWNER_EMAIL are specified
IF "%~1"=="" goto :needparams
IF "%~2"=="" goto :needparams
IF NOT "%~3"=="" goto :needparams

:: download Vanta
curl -o vanta-installer.exe https://vanta-agent.s3.amazonaws.com/v1.5.0/vanta-installer.exe

:: write config files
mkdir C:\ProgramData\Vanta
echo {"AGENT_KEY": "%1", "NEEDS_OWNER": true, "OWNER_EMAIL": "%2"} > C:\ProgramData\Vanta\vanta.conf

:: set permissions on config files so installer doesn't overwrite
icacls C:\ProgramData\Vanta\enroll_secret.txt /grant Everyone:R
icacls C:\ProgramData\Vanta\vanta.conf /grant Everyone:R
icacls C:\ProgramData\Vanta\enroll_secret.txt /deny Everyone:W
icacls C:\ProgramData\Vanta\vanta.conf /deny Everyone:W

:: install vanta
vanta-installer.exe /S

EXIT

:needparams
echo Usage: "install-vanta.bat [AGENT_KEY] [OWNER_EMAIL]"
exit /B 1
