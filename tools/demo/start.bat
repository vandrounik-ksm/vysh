@echo off
rem Demo stand for vysh screenshots: 5 SSH servers in Docker + separate vysh profile.
rem Needs Docker Desktop and ssh-keygen (built into Windows 10/11).
setlocal
set "DEMO=%TEMP%\vysh-demo"
if not exist "%DEMO%" mkdir "%DEMO%"

if not exist "%DEMO%\demo_key" (
  ssh-keygen -q -t ed25519 -N "" -C vysh-demo -f "%DEMO%\demo_key" || exit /b 1
)

set "VYSH_DEMO_DIR=%DEMO%"
docker compose -f "%~dp0docker-compose.yml" up -d --build || exit /b 1

rem Hosts with the key path; JSON is written without BOM.
set "KEY=%DEMO%\demo_key"
set "KEY=%KEY:\=/%"
powershell -NoProfile -Command "[IO.File]::WriteAllText('%DEMO%\hosts.json', ((Get-Content -Raw '%~dp0hosts.json') -replace '__KEY__','%KEY%'))" || exit /b 1
if not exist "%DEMO%\settings.json" copy /Y "%~dp0settings.json" "%DEMO%\settings.json" >nul

echo.
echo Servers are up. Starting vysh with demo profile: %DEMO%
set "VYSH_CONFIG_DIR=%DEMO%"
cd /d "%~dp0..\.."
flutter run -d windows --release
