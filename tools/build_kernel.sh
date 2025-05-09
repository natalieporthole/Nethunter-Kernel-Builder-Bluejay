#!/bin/bash
# Script to build a custom kernel for the Google Pixel 6a
# This script is designed to be run on a Debian-based system
# It will install necessary dependencies, clone the kernel source,
# apply patches, and build the kernel for the Pixel 6a device.  

set -e

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directory setup
BASEDIR=$(pwd)
KERNELDIR="${BASEDIR}/kernel"
OUTPUTDIR="${BASEDIR}/output"
PATCHDIR="${BASEDIR}/patches"
CONFIG_FILE="${BASEDIR}/kernel_config.ini"

# Parse configuration
KERNEL_NAME=$(grep "name=" ${CONFIG_FILE} | cut -d '=' -f2)
DEVICE=$(grep "device=" ${CONFIG_FILE} | cut -d '=' -f2)
CODENAME=$(grep "codename=" ${CONFIG_FILE} | cut -d '=' -f2)
LINEAGE_BRANCH=$(grep "lineage_branch=" ${CONFIG_FILE} | cut -d '=' -f2)
KERNEL_SOURCE=$(grep "kernel_source=" ${CONFIG_FILE} | cut -d '=' -f2)
CLONE_DEPTH=$(grep "clone_depth=" ${CONFIG_FILE} | cut -d '=' -f2)
DEFCONFIG=$(grep "defconfig=" ${CONFIG_FILE} | cut -d '=' -f2)

# Function to build the kernel
build_kernel() {
    echo -e "\n${YELLOW}Building NetHunter kernel for Pixel 6a...${NC}"
    cd ${KERNELDIR}
    
    # Setup compiler environment
    export ARCH=arm64
    export SUBARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    
    # Pixel 6a specific - Using Google's Clang compiler
    export USE_CLANG=1
    export CLANG_TRIPLE=aarch64-linux-gnu-
    
    # Setup build options for Tensor chip
    MAKE_OPTS="-j$(nproc --all) O=out \
        ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-"
    
    # Prepare build environment
    mkdir -p out

    # Prepare kernel configuration
    echo -e "${BLUE}Preparing Pixel 6a kernel configuration...${NC}"
    make ${MAKE_OPTS} ${DEFCONFIG}
    
    # Enable additional configs for Pixel 6a
    scripts/config --file out/.config \
        --set-str CONFIG_LOCALVERSION "-NetHunter-Bluejay" \
        --enable CONFIG_OVERLAY_FS \
        --enable CONFIG_ASYMMETRIC_KEY_TYPE \
        --enable CONFIG_ASYMMETRIC_PUBLIC_KEY_SUBTYPE \
        --enable CONFIG_SYSTEM_TRUSTED_KEYRING \
        --enable CONFIG_WIRELESS_EXT \
        --enable CONFIG_WEXT_CORE \
        --enable CONFIG_WEXT_PROC \
        --enable CONFIG_WEXT_SPY \
        --enable CONFIG_WEXT_PRIV \
        --enable CONFIG_CFG80211_WEXT \
        --enable CONFIG_USB_RTL8152 \
        --enable CONFIG_RTL8153_ECM

    # Build the kernel
    echo -e "${BLUE}Building kernel...${NC}"
    make ${MAKE_OPTS}
    
    # Check if kernel build was successful
    if [ -f "out/arch/arm64/boot/Image.lz4" ]; then
        echo -e "${GREEN}Kernel build successful!${NC}"
        
        mkdir -p ${OUTPUTDIR}
        
        # Copy kernel image and DTB files
        cp out/arch/arm64/boot/Image.lz4 ${OUTPUTDIR}/
        cp out/arch/arm64/boot/dts/google/*.dtb ${OUTPUTDIR}/
        
        # Create boot image package
        echo -e "${BLUE}Creating boot image package...${NC}"
        cat ${OUTPUTDIR}/Image.lz4 ${OUTPUTDIR}/*.dtb > ${OUTPUTDIR}/Image.lz4-dtb
        
        echo -e "${GREEN}Kernel files saved to ${OUTPUTDIR}${NC}"
    else
        echo -e "${RED}Kernel build failed!${NC}"
        exit 1
    fi
}

# Function to install required dependencies
install_dependencies() {
    echo -e "\n${YELLOW}Installing required dependencies...${NC}"
    
    if [ -f /etc/debian_version ]; then
        sudo apt update
        sudo apt install -y \
            git ccache automake flex lzop bison \
            gperf build-essential zip curl zlib1g-dev \
            clang libssl-dev libc6-dev-i386 \
            libncurses5-dev libncurses5 \
            gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
            python3 python3-pip \
            bc kmod cpio libssl-dev \
            device-tree-compiler lz4 \
            binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi
    else
        echo -e "${RED}Please install the required dependencies manually for your distribution${NC}"
        exit 1
    fi
}

# Main execution
main() {
    # Install dependencies
    install_dependencies
    
    # Create output directory
    mkdir -p ${OUTPUTDIR}
    
    # Clone kernel source
    clone_kernel_source

    # Apply NetHunter patches
    apply_patches

    # Modify kernel config
    modify_kernel_config
    
    # Build the kernel
    build_kernel
    
    echo -e "\n${GREEN}NetHunter kernel build complete!${NC}"
    echo -e "${BLUE}Kernel can be found at:${NC} ${OUTPUTDIR}/Image.lz4-dtb"
}


