@echo off
cd /d "%~dp0"
if not exist game\export-templates\web_nothreads_release.zip node download-web-template.mjs
if not exist game\export-templates\web_dlink_release.zip node download-web-template.mjs
set "GODOT_BIN=D:\Create\Godot\Godot_v4.7.2-stable_win64_console.exe"
node build-web.mjs
pause
