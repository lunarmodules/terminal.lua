@echo off
if exist "C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin\lua.exe" for /f "usebackq delims=" %%p in (`""C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin\lua" "C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin\get_deactivated_path.lua""`) DO set "PATH=%%p"
