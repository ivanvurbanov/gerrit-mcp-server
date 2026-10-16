@echo off
setlocal enabledelayedexpansion

rem This script builds the Gerrit MCP server by setting up its Python environment.

set "SERVER_DIR=."
set "REQUIREMENTS_FILE=requirements.txt"
set "VENV_DIR=.venv"

echo.
echo Setting up the Python environment for the Gerrit MCP server...
set "PIP_NO_INDEX="
set "PIP_DISABLE_PIP_VERSION_CHECK=1"

set "BUILD_TMP=%CD%\\build\\tmp"
if not exist "%BUILD_TMP%" mkdir "%BUILD_TMP%"
set "TEMP=%BUILD_TMP%"
set "TMP=%BUILD_TMP%"

if not exist "build" mkdir "build"

echo Creating virtual environment in %VENV_DIR%...
rem Prefer the highest available Python >= 3.12 (py launcher if present, else python in PATH).
powershell -NoProfile -Command ^
  "$py = $null; " ^
  "if (Get-Command py -ErrorAction SilentlyContinue) { " ^
  "  $lines = & py -0p 2>$null; " ^
  "  foreach ($line in $lines) { " ^
  "    if ($line -match '^\s*-(\d+\.\d+)\S*\s+(.+)$') { " ^
  "      $ver = [version]$matches[1]; " ^
  "      if ($ver -ge [version]'3.12') { " ^
  "        if (-not $py -or $ver -gt $py.Ver) { " ^
  "          $py = [pscustomobject]@{ Ver = $ver; Path = $matches[2] } " ^
  "        } " ^
  "      } " ^
  "    } " ^
  "  } " ^
  "} " ^
  "if (-not $py) { " ^
  "  $cmd = Get-Command python -ErrorAction SilentlyContinue; " ^
  "  if ($cmd) { " ^
  "    $ver = & $cmd.Source -c \"import sys; print('%%d.%%d' %% sys.version_info[:2])\"; " ^
  "    if ([version]$ver -ge [version]'3.12') { " ^
  "      $py = [pscustomobject]@{ Ver = [version]$ver; Path = $cmd.Source } " ^
  "    } " ^
  "  } " ^
  "} " ^
  "if (-not $py) { Write-Error 'No suitable Python (>= 3.12) found.'; exit 1 } " ^
  "& $py.Path -m venv \"$env:VENV_DIR\""
if errorlevel 1 (
  echo venv creation failed. Falling back to virtualenv...
  if exist "%VENV_DIR%" rmdir /s /q "%VENV_DIR%"
  python -m pip install --user --index-url https://pypi.org/simple virtualenv
  if errorlevel 1 (
    echo Failed to install virtualenv. Check internet access or pip index configuration.
    exit /b 1
  )
  python -m virtualenv "%VENV_DIR%"
  if errorlevel 1 (
    echo Failed to create virtual environment with virtualenv.
    exit /b 1
  )
)

call "%VENV_DIR%\Scripts\activate.bat"
if errorlevel 1 (
  echo Failed to activate virtual environment.
  exit /b 1
)

where uv >nul 2>nul
if errorlevel 1 (
  echo uv not found on PATH, installing via pip with hash verification...
  pip install --require-hashes -r "%REQUIREMENTS_FILE%"
  if errorlevel 1 (
    echo Failed to install uv. Install it manually: https://docs.astral.sh/uv/getting-started/installation/
    exit /b 1
  )
)

echo Installing dependencies into %VENV_DIR% and syncing uv.lock...
uv sync --extra dev
if errorlevel 1 (
  echo Failed to install dependencies.
  exit /b 1
)

echo.
echo Successfully set up the Gerrit MCP server environment.
exit /b 0
