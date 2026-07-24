#!/bin/bash

# Check if the argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <org>/<package_name>:<version>"
    exit 1
fi

# Extract the organization, package name, and version from the argument
input="$1"
org_pkg_version=$(echo "$input" | awk -F':' '{print $1}')
version=$(echo "$input" | awk -F':' '{print $2}')

# Split org and package name
org=$(echo "$org_pkg_version" | awk -F'/' '{print $1}')
pkg_name=$(echo "$org_pkg_version" | awk -F'/' '{print $2}')

# If version is 'latest', fetch it from the API
if [ "$version" == "latest" ]; then
    # Call the version API
    version=$(curl -s "https://api.gingersociety.org/metadata/version/$org/$pkg_name")

    if [ -z "$version" ]; then
        echo "Error: Could not retrieve the latest version for $org/$pkg_name"
        exit 1
    fi
fi

# Function to detect the operating system
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "apple-darwin"
            ;;
        Linux)
            echo "unknown-linux-gnu"
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*)
            echo "pc-windows-gnu"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to detect CPU architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "x86_64"
            ;;
        arm64)
            echo "aarch64"
            ;;
        aarch64)
            echo "aarch64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect the architecture and OS
arch=$(detect_arch)
os=$(detect_os)

# Check for unsupported configurations
if [ "$arch" == "unknown" ] || [ "$os" == "unknown" ]; then
    echo "Unsupported system: arch=$arch, os=$os"
    exit 1
fi

# Format the URL
# url="https://$pkg_name-binaries.s3.ap-south-1.amazonaws.com/$version/$arch-$os/$pkg_name"
url="https://bucket.gingersociety.org/files/$pkg_name-binaries/$version/$arch-$os/$pkg_name"

# Output the formatted URL
echo "Download URL: $url"

# Set the destination directory based on the OS
case "$os" in
    "apple-darwin")
        dest_dir="/usr/local/bin"
        ;;
    "unknown-linux-gnu")
        dest_dir="/usr/local/bin"
        ;;
    "pc-windows-gnu")
        dest_dir="/c/Program Files"
        ;;
    *)
        echo "Unsupported operating system."
        exit 1
        ;;
esac

# Check if the destination directory exists and is writable
if [ ! -d "$dest_dir" ] || [ ! -w "$dest_dir" ]; then
    echo "Destination directory $dest_dir is not writable or does not exist."
    exit 1
fi

# Download the binary using curl
echo "Downloading the binary..."
curl -L "$url" -o "$dest_dir/$pkg_name" --fail

# Make the binary executable (skip this for Windows)
if [ "$os" != "pc-windows-gnu" ]; then
    chmod +x "$dest_dir/$pkg_name"
fi

# Confirm download and installation
if [ -f "$dest_dir/$pkg_name" ]; then
    echo "Binary successfully downloaded and installed to $dest_dir/$pkg_name"
else
    echo "Failed to download the binary."
    exit 1
fi
