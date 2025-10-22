#!/bin/bash
# Script for building and packaging RedisClient native component for 1C

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="${SCRIPT_DIR}/build"
PACKAGE_DIR="${SCRIPT_DIR}/package"

echo "=== Building RedisClient Native AddIn for 1C ==="
echo ""

# Check if Conan is installed
if ! command -v conan &> /dev/null; then
    echo "Error: Conan is not installed. Please install it first:"
    echo "  pip install conan"
    exit 1
fi

# Check if CMake is installed
if ! command -v cmake &> /dev/null; then
    echo "Error: CMake is not installed. Please install it first."
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
rm -rf "${PACKAGE_DIR}"

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Install dependencies via Conan
echo ""
echo "=== Installing dependencies via Conan ==="
conan install .. --build=missing -s arch=x86_64 -s build_type=Release -s compiler.cppstd=17 -of .

# Generate CMake project
echo ""
echo "=== Generating CMake project ==="
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake

# Build the project
echo ""
echo "=== Building the project ==="
cmake --build . --config Release

# Check if build was successful
if [ -f "libRedisClientAddIn.so" ]; then
    LIB_FILE="libRedisClientAddIn.so"
elif [ -f "libRedisClientAddIn.dylib" ]; then
    LIB_FILE="libRedisClientAddIn.dylib"
elif [ -f "RedisClientAddIn.dll" ]; then
    LIB_FILE="RedisClientAddIn.dll"
else
    echo "Error: Build failed. Library file not found."
    exit 1
fi

echo ""
echo "=== Build successful! ==="
echo "Library file: ${LIB_FILE}"

# Create package directory
echo ""
echo "=== Creating package for 1C ==="
mkdir -p "${PACKAGE_DIR}"

# Copy library to package directory
cp "${LIB_FILE}" "${PACKAGE_DIR}/"

# Create manifest.xml
cat > "${PACKAGE_DIR}/manifest.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<bundle xmlns="http://v8.1c.ru/8.2/addin/bundle">
    <component os="Windows" arch="i386" path="RedisClientAddIn.dll"/>
    <component os="Windows" arch="x86_64" path="RedisClientAddIn.dll"/>
    <component os="Linux" arch="i386" path="libRedisClientAddIn.so"/>
    <component os="Linux" arch="x86_64" path="libRedisClientAddIn.so"/>
    <component os="macOS" arch="x86_64" path="libRedisClientAddIn.dylib"/>
</bundle>
EOF

# Create ZIP archive
cd "${PACKAGE_DIR}"
ZIP_FILE="${SCRIPT_DIR}/RedisClient.zip"
rm -f "${ZIP_FILE}"

if command -v zip &> /dev/null; then
    zip -r "${ZIP_FILE}" *
    echo ""
    echo "=== Package created successfully! ==="
    echo "ZIP file: ${ZIP_FILE}"
else
    echo ""
    echo "=== Package directory created ==="
    echo "Location: ${PACKAGE_DIR}"
    echo ""
    echo "Note: 'zip' command not found. Please create ZIP archive manually:"
    echo "  cd ${PACKAGE_DIR}"
    echo "  zip -r ${ZIP_FILE} *"
fi

echo ""
echo "=== Next steps ==="
echo "1. Use the ZIP archive to install the component in 1C"
echo "2. In 1C Configurator, go to 'External Components'"
echo "3. Add new component and upload ${ZIP_FILE}"
echo "4. Set identifier: AddIn.RedisClient"
echo ""
echo "Done!"
