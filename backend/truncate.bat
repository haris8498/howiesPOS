@echo off
echo ===================================================
echo   Truncating Orders, Calculations, and Sync Logs
echo ===================================================

echo [1/2] Ensuring PostgreSQL service is running...
net start postgresql-x64-18 >nul 2>&1

echo [2/2] Executing TRUNCATE script...
node "%~dp0truncate_tables.js"

echo ===================================================
pause

