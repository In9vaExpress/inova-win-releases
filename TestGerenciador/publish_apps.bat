@echo off
cd /d "%~dp0"
title Publicador de Aplicativos e DLLs Inova Win
powershell -NoProfile -ExecutionPolicy Bypass -File .\publish_apps.ps1
pause
