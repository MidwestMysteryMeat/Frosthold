@echo off
:: FROSTHOLD Sprite Editor Launcher
:: Finds love.exe and runs the sprite editor from this directory.

setlocal

:: %~dp0 has a trailing backslash which breaks quoting — strip it
set "EDITORDIR=%~dp0"
set "EDITORDIR=%EDITORDIR:~0,-1%"

:: Check common install locations for love.exe
where love.exe >nul 2>&1 && (
    love.exe "%EDITORDIR%"
    exit /b
)

if exist "%ProgramFiles%\LOVE\love.exe" (
    "%ProgramFiles%\LOVE\love.exe" "%EDITORDIR%"
    exit /b
)

if exist "%ProgramFiles(x86)%\LOVE\love.exe" (
    "%ProgramFiles(x86)%\LOVE\love.exe" "%EDITORDIR%"
    exit /b
)

if exist "%LocalAppData%\Programs\LOVE\love.exe" (
    "%LocalAppData%\Programs\LOVE\love.exe" "%EDITORDIR%"
    exit /b
)

echo ERROR: love.exe not found.
echo Install Love2D from https://love2d.org and ensure love.exe is on your PATH.
pause
