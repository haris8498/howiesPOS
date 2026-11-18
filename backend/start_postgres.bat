@echo off
title PostgreSQL 18 Server
echo ===================================================
echo   Hungry Howie's POS - Local PostgreSQL 18
echo ===================================================
echo Starting PostgreSQL on 127.0.0.1:5432...
"C:\Program Files\PostgreSQL\18\bin\postgres.exe" -D "C:\Program Files\PostgreSQL\18\data" -h 127.0.0.1 -p 5432
pause
