@echo off
echo ===================================================
echo   Hungry Howie's POS - Local PostgreSQL Setup
echo ===================================================

echo [1/3] Ensuring PostgreSQL service is running...
net start postgresql-x64-18 >nul 2>&1

echo [2/3] Synchronizing schema with Prisma...
call npx prisma db push

echo [3/3] Seeding initial data...
call npx prisma db seed

echo ===================================================
echo   Local database setup complete!
echo ===================================================
pause

