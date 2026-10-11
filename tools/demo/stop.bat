@echo off
rem Stop demo servers. Profile in %TEMP%\vysh-demo stays; delete it to start fresh.
set "VYSH_DEMO_DIR=%TEMP%\vysh-demo"
docker compose -f "%~dp0docker-compose.yml" down
