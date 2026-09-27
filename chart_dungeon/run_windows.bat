@echo off
rem Chart Dungeon launcher for Windows.
rem First run downloads Godot 4.4.1 (about 70 MB) into .godot_bin, prepares the game files, then starts the game.
setlocal
cd /d "%~dp0"
set "VER=4.4.1-stable"
set "BIN=%~dp0.godot_bin"
set "EXE=%BIN%\Godot_v%VER%_win64.exe"
set "CON=%BIN%\Godot_v%VER%_win64_console.exe"

if not exist "%EXE%" (
  echo Downloading Godot %VER% ...
  if not exist "%BIN%" mkdir "%BIN%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/godotengine/godot/releases/download/%VER%/Godot_v%VER%_win64.exe.zip' -OutFile '%BIN%\godot.zip'; Expand-Archive -Force '%BIN%\godot.zip' '%BIN%'; Remove-Item '%BIN%\godot.zip'"
)
if not exist "%EXE%" (
  echo Download failed. Install Godot 4.4 from https://godotengine.org and open project.godot instead.
  pause
  exit /b 1
)
type nul > "%BIN%\.gdignore"

if not exist ".godot\imported" (
  echo Preparing game files ^(first run only^) ...
  "%CON%" --headless --path . --import >nul 2>&1
  "%CON%" --headless --path . --import >nul 2>&1
)
start "" "%EXE%" --path .
