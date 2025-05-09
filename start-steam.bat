@echo off
title Steam Process Manager
chcp 65001 > nul
cls

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%steam_manager.ps1"

echo [DEBUG] Проверка PowerShell скрипта...
if not exist "%PS_SCRIPT%" (
    echo [ERROR] Файл %PS_SCRIPT% не найден!
    pause
    exit /b 1
)

fltmc >nul 2>&1 || goto elevate

echo [DEBUG] Запуск основного сценария...
call :run_ps

:: Фиксируем окно после выполнения
echo [DEBUG] Завершение работы. Нажмите любую клавишу...
pause >nul
exit /b

:elevate
echo [ADMIN] Запрос прав администратора...
powershell -Command "Start-Process cmd -ArgumentList '/k','""%~f0""'" -Verb RunAs
exit /b

:run_ps
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -NoProfile
if %errorlevel% neq 0 (
    echo [ERROR] Ошибка выполнения (код: %errorlevel%)!
    pause
    exit /b %errorlevel%
)
exit /b