@echo off
echo ===================================================
echo   Hungry Howie's POS - Truncate Database Tables
echo ===================================================

echo [1/2] Ensuring PostgreSQL service is running...
net start postgresql-x64-18 >nul 2>&1

echo [2/2] Truncating orders and transactional tables...
cd /d "%~dp0"
call npx ts-node -T prisma/truncate_tables.ts

echo ===================================================
echo   Done!
echo ===================================================
pause
