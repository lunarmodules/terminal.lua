@echo off
where deactivate-lua >nul 2>nul
if %errorlevel% equ 0 call deactivate-lua
set "PATH=C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin;%PATH%"
