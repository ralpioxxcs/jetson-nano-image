#! /bin/bash

#
# Author: Badr BADRI © pythops
# Modifier: ralpioxxcs
#

#-----------------------------------------------
# predefined environment variables
# * JETSON_ROOTFS_DIR : root filesystem directory (create-rootfs stage)
# * JETSON_BUILD_DIR  : build output directory
# * JETSON_NANO_BOARD_TYPE : "4gb" or "2gb"
# * JETSON_NANO_BOARD_CONFIG : "jetson-nano"
# * JETSON_NANO_REVISION (default: 300)
# * JETSON_NANO_BLOB_NAME : output image filename
# 
# ?       sd_blob_name    - valid file name
# ?       board           - board name. Supported boards are:
# ?                          jetson-nano
# ?                          jetson-nano-2gb-devkit
# ?                          jetson-xavier-nx-devkit
# ?       revision        - SKU revision number
# ?                          jetson-nano: 100/200/300 for A01/A02/B00
# ?                          jetson-nano-2gb-devkit: default
# ?                          jetson-xavier-nx-devkit: default
#-----------------------------------------------

set -e

printf "envs\n"

# L4T (32.5.1)
bsp=https://developer.nvidia.com/embedded/l4t/r32_release_v5.2/t210/jetson-210_linux_r32.5.2_aarch64.tbz2

# Check if the user is not root
if [ "x$(whoami)" != "xroot" ]; then
        printf "\e[31mThis script requires root privilege\e[0m\n"
        exit 1
fi

# Check for env variables
if [ ! ${JETSON_ROOTFS_DIR} ] || [ ! ${JETSON_BUILD_DIR} ]; then
	printf "\e[31mYou need to set the env variables \${JETSON_ROOTFS_DIR} and \${JETSON_BUILD_DIR}\e[0m\n"
	exit 1
fi

# Check if ${JETSON_ROOTFS_DIR} if not empty
if [ ! "$(ls -A ${JETSON_ROOTFS_DIR})" ]; then
	printf "\e[31mNo rootfs found in ${JETSON_ROOTFS_DIR}\e[0m\n"
	exit 1
fi

# Check if board type is specified
if [ ! ${JETSON_NANO_BOARD_TYPE} ]; then
	printf "\e[31mJetson nano board type must be specified\e[0m\n"
	exit 1
fi

printf "\e[32mBuild the image ...\n"

# Create the build dir if it does not exists
mkdir -p ${JETSON_BUILD_DIR}

# Download L4T
if [ ! "$(ls -A ${JETSON_BUILD_DIR})" ]; then
        printf "\e[32mDownload L4T...       "
        wget -qO- ${bsp} | tar -jxpf - -C ${JETSON_BUILD_DIR}
	rm ${JETSON_BUILD_DIR}/Linux_for_Tegra/rootfs/README.txt
        printf "[OK]\n"
fi

cp -rp ${JETSON_ROOTFS_DIR}/*  ${JETSON_BUILD_DIR}/Linux_for_Tegra/rootfs/ > /dev/null

# patch ${JETSON_BUILD_DIR}/Linux_for_Tegra/nv_tegra/nv-apply-debs.sh < patches/nv-apply-debs.diff

pushd ${JETSON_BUILD_DIR}/Linux_for_Tegra/ > /dev/null

printf "Extract L4T...        "
./apply_binaries.sh > /dev/null
printf "[OK]\n"

pushd ${JETSON_BUILD_DIR}/Linux_for_Tegra/tools

# [USAGE]
# ./jetson-disk-image-creator.sh -o <blob_name> -b <board> -r <revision>
#
# [revision number]
# B00, B01 = 300
# A02 = 200
# A01 = 100
case "${JETSON_NANO_BOARD_TYPE}" in
    2gb)
        printf "Create image for Jetson nano 2GB board"
        ./jetson-disk-image-creator.sh -o jetson.img -b jetson-nano-2gb-devkit
        printf "OK\n"
        ;;

    4gb)
        revision=${JETSON_NANO_REVISION:=300}
        printf "Create image for Jetson nano board (%s revision)\n" ${revision}
        printf "/jetson-disk-image-creator.sh -o ${JETSON_NANO_BLOB_NAME} -b ${JETSON_NANO_BOARD_CONFIG} -r ${revision}"
        ./jetson-disk-image-creator.sh -o ${JETSON_NANO_BLOB_NAME} -b ${JETSON_NANO_BOARD_CONFIG} -r ${revision}
        printf "OK\n"
        ;;

    *)
	printf "\e[31mUnknown Jetson nano board type\e[0m\n"
	exit 1
        ;;
esac

printf "\e[32mImage created successfully\n"
printf "Image location: ${JETSON_BUILD_DIR}/Linux_for_Tegra/tools/${JETSON_NANO_BLOB_NAME}\n"