@echo off
title WebADB Local Server
echo ====================================================
echo Starting WebADB Local Server (https://localhost:5173)
echo ====================================================
echo.
cd /d "%~dp0"
call npm run dev
pause
