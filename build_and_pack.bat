@echo off
REM Script for building and packaging RedisClient native component for 1C (Windows)

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build"
set "PACKAGE_DIR=%SCRIPT_DIR%package"

echo === Building RedisClient Native AddIn for 1C (Windows) ===
echo.

REM Check if Python is installed
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Python is not installed. Please install Python first.
    exit /b 1
)

REM Check if Conan is installed
where conan >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Conan is not installed. Please install it first:
    echo   pip install conan
    exit /b 1
)

REM Check if CMake is installed
where cmake >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: CMake is not installed. Please install it first.
    exit /b 1
)

REM Clean previous builds
echo Cleaning previous builds...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%PACKAGE_DIR%" rmdir /s /q "%PACKAGE_DIR%"

REM Create build directory
mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

REM Install dependencies via Conan
echo.
echo === Installing dependencies via Conan ===
conan install .. --build=missing -s arch=x86_64 -s build_type=Release -s compiler.cppstd=17 -of .
if %errorlevel% neq 0 (
    echo Error: Conan install failed
    exit /b 1
)

REM Generate CMake project
echo.
echo === Generating CMake project ===
cmake .. -G "Visual Studio 16 2019" -A x64 -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake
if %errorlevel% neq 0 (
    echo Error: CMake generation failed. Trying with default generator...
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake
    if %errorlevel% neq 0 (
        echo Error: CMake generation failed
        exit /b 1
    )
)

REM Build the project
echo.
echo === Building the project ===
cmake --build . --config Release
if %errorlevel% neq 0 (
    echo Error: Build failed
    exit /b 1
)

REM Find the built library
set "LIB_FILE="
if exist "Release\RedisClientAddIn.dll" (
    set "LIB_FILE=Release\RedisClientAddIn.dll"
) else if exist "RedisClientAddIn.dll" (
    set "LIB_FILE=RedisClientAddIn.dll"
)

if "%LIB_FILE%"=="" (
    echo Error: Build failed. Library file not found.
    exit /b 1
)

echo.
echo === Build successful! ===
echo Library file: %LIB_FILE%

REM Create package directory
echo.
echo === Creating package for 1C ===
mkdir "%PACKAGE_DIR%"

REM Copy library to package directory
copy "%LIB_FILE%" "%PACKAGE_DIR%\"

REM Create manifest.xml
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<bundle xmlns="http://v8.1c.ru/8.2/addin/bundle"^>
echo     ^<component os="Windows" arch="i386" path="RedisClientAddIn.dll"/^>
echo     ^<component os="Windows" arch="x86_64" path="RedisClientAddIn.dll"/^>
echo     ^<component os="Linux" arch="i386" path="libRedisClientAddIn.so"/^>
echo     ^<component os="Linux" arch="x86_64" path="libRedisClientAddIn.so"/^>
echo ^</bundle^>
) > "%PACKAGE_DIR%\manifest.xml"

REM Create ZIP archive
cd /d "%PACKAGE_DIR%"
set "ZIP_FILE=%SCRIPT_DIR%RedisClient.zip"
if exist "%ZIP_FILE%" del "%ZIP_FILE%"

REM Try to use PowerShell to create ZIP
powershell -Command "Compress-Archive -Path '%PACKAGE_DIR%\*' -DestinationPath '%ZIP_FILE%' -Force" 2>nul
if %errorlevel% equ 0 (
    echo.
    echo === Package created successfully! ===
    echo ZIP file: %ZIP_FILE%
) else (
    echo.
    echo === Package directory created ===
    echo Location: %PACKAGE_DIR%
    echo.
    echo Note: PowerShell ZIP creation failed. Please create ZIP archive manually:
    echo   Right-click on folder %PACKAGE_DIR%
    echo   Select "Send to" ^> "Compressed (zipped) folder"
    echo   Rename to RedisClient.zip
)

echo.
echo === Next steps ===
echo 1. Use the ZIP archive to install the component in 1C
echo 2. In 1C Configurator, go to 'External Components'
echo 3. Add new component and upload %ZIP_FILE%
echo 4. Set identifier: AddIn.RedisClient
echo.
echo Done!

cd /d "%SCRIPT_DIR%"
pause
