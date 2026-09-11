@echo off
cd /d "%~dp0"
if not exist web mkdir web
"D:\Create\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --export-release Web ../web/index.html
pause
