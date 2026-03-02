@echo off
REM Anchor Engine Node.js Setup Script for Android (Windows)
REM This script prepares the anchor-engine-node for bundling with the Flutter app

echo.
echo ========================================
echo  Anchor Engine Setup for Android
echo ========================================
echo.

set SCRIPT_DIR=%~dp0
set SERVICES_DIR=%SCRIPT_DIR%services
set ENGINE_DIR=%SERVICES_DIR%\engine-source
set FLUTTER_ASSETS=%SCRIPT_DIR%flutter_app\android\app\src\main\assets

echo [1/6] Creating directories...
if not exist "%SERVICES_DIR%" mkdir "%SERVICES_DIR%"
if not exist "%FLUTTER_ASSETS%\engine" mkdir "%FLUTTER_ASSETS%\engine"

echo.
echo [2/6] Checking for engine source...
if exist "%ENGINE_DIR%" (
    echo Engine source exists. Updating...
    cd /d "%ENGINE_DIR%"
    git pull
) else (
    echo Cloning anchor-engine-node repository...
    git clone https://github.com/RSBalchII/anchor-engine-node.git "%ENGINE_DIR%"
)

echo.
echo [3/6] Installing dependencies...
cd /d "%ENGINE_DIR%"

REM Check if pnpm is installed
where pnpm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo pnpm not found. Installing globally...
    npm install -g pnpm
)

REM Install dependencies
call pnpm install

echo.
echo [4/6] Building engine...
call pnpm run build

echo.
echo [5/6] Preparing bundle...
set BUNDLE_DIR=%SERVICES_DIR%\engine-bundle
if exist "%BUNDLE_DIR%" rmdir /s /q "%BUNDLE_DIR%"
mkdir "%BUNDLE_DIR%"

REM Copy necessary files
xcopy /E /I /Y "%ENGINE_DIR%\dist" "%BUNDLE_DIR%\dist"
xcopy /E /I /Y "%ENGINE_DIR%\node_modules" "%BUNDLE_DIR%\node_modules"
copy /Y "%ENGINE_DIR%\package.json" "%BUNDLE_DIR%\"
copy /Y "%ENGINE_DIR%\user_settings.json" "%BUNDLE_DIR%\" 2>nul || echo No user_settings.json found

echo.
echo [6/6] Creating compressed bundle...
cd /d "%SERVICES_DIR%"
REM Note: tar might not be available on all Windows systems
REM Alternative: Use 7-Zip or WinRAR
if exist "engine-bundle.tar.gz" del "engine-bundle.tar.gz"
tar -czf engine-bundle.tar.gz engine-bundle\ 2>nul || (
    echo Note: tar command failed. You can manually compress the bundle.
    echo Bundle directory: %BUNDLE_DIR%
)

echo.
echo ========================================
echo  Setup Complete!
echo ========================================
echo.
echo Engine bundle created at: %SERVICES_DIR%\engine-bundle.tar.gz
echo.
echo To bundle with Flutter app:
echo   1. Extract to: flutter_app\android\app\src\main\assets\engine\
echo   2. Or use the tarball in your build process
echo.
echo Next steps:
echo   - Update pubspec.yaml for native assets
echo   - Configure Android Gradle for Node.js runtime
echo   - Test engine startup on Android device
echo.
pause
