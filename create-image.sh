#! /bin/bash

#
# Author: Badr BADRI © pythops
# Modifier: ralpioxxcs
#

# @brief : Create flashable image (.img) file each jetson board type
# @env :
#   * JETSON_ROOTFS_DIR - root filesystem directory (create-rootfs stage)
#   * JETSON_BUILD_DIR  - build output directory
#
#   [[optional envs]]
#   * JETSON_NANO_STORAGE_TYPE  - "emmc" or "sd" (https://developer.nvidia.com/embedded/faq#jetson-devkit-vs-module)
#   * JETSON_NANO_MEMORY_TYPE   - memory type (default: "4g", available : 4gb, 2gb)
#   * JETSON_NANO_REVISION      - SKU revision number (default: "300")
#                                 * available : 
#                                   jetson-nano: 100/200/300 for A01/A02/B00
#                                   jetson-nano-2gb-devkit: default
#                                   jetson-xavier-nx-devkit: default
#   * JETSON_NANO_SD_BLOB_NAME  - valid file name (default: "jetson.img")
#

set -e

# L4T Version archives
bsp_32_6_1=https://developer.nvidia.com/embedded/l4t/r32_release_v6.1/t210/jetson-210_linux_r32.6.1_aarch64.tbz2
bsp_32_5_2=https://developer.nvidia.com/embedded/l4t/r32_release_v5.2/t210/jetson-210_linux_r32.5.2_aarch64.tbz2
bsp_32_5_1=https://developer.nvidia.com/embedded/l4t/r32_release_v5.2/t210/jetson-210_linux_r32.5.2_aarch64.tbz2
bsp_32_5=https://developer.nvidia.com/embedded/L4T/r32_Release_v5.0/T210/Tegra210_Linux_R32.5.0_aarch64.tbz2

while true; do
  echo "Select L4T Version"
  echo "1) 32.6.1"
  echo "2) 32.5.2"
  echo "3) 32.5.1"
  echo "4) 32.5"
  read ans

  if [ "$ans" != "${ans#[1]}" ] ;then
    bsp=${bsp_32_6_1}
    break
  elif [ "$ans" != "${ans#[2]}" ] ;then
    bsp=${bsp_32_5_2}
    break
  elif [ "$ans" != "${ans#[3]}" ] ;then
    bsp=${bsp_32_5_1}
    break
  elif [ "$ans" != "${ans#[4]}" ] ;then
    bsp=${bsp_32_5}
    break
  else
    echo "Please select valid number"
  fi
done

# Check if the user is not root
if [ "x$(whoami)" != "xroot" ]; then
        printf "\e[31mThis script requires root privilege\e[0m\n"
        exit 1
fi

# Check for env variables
if [ ! ${JETSON_ROOTFS_DIR} ] || [ ! ${JETSON_BUILD_DIR} ]; then
	printf "\e[31mYou need to set the env variables \"JETSON_ROOTFS_DIR\" and \"JETSON_BUILD_DIR\" \e[0m\n"
	exit 1
fi

# Check if "JETSON_ROOTFS_DIR" if not empty
if [ ! "$(ls -A ${JETSON_ROOTFS_DIR})" ]; then
	printf "\e[31mNo rootfs found in \"${JETSON_ROOTFS_DIR}\"\e[0m\n"
	exit 1
fi

# Check optional variables 
if [ ! ${JETSON_NANO_STORAGE_TYPE} ]; then
        export JETSON_NANO_STORAGE_TYPE=emmc
	printf "\e[33mtype is not specified,, use predefined (${JETSON_NANO_STORAGE_TYPE})\e[0m\n"
fi
if [ ! ${JETSON_NANO_MEMORY_TYPE} ]; then
        export JETSON_NANO_MEMORY_TYPE=4gb
	printf "\e[33mboard type is not specified,, use predefined (${JETSON_NANO_MEMORY_TYPE})\e[0m\n"
fi
if [ ! ${JETSON_NANO_REVISION} ]; then
        export JETSON_NANO_REVISION=300
	printf "\e[33mboard revision is not specified,, use predefined (${JETSON_NANO_REVISION})\e[0m\n"
fi
if [ ! ${JETSON_NANO_SD_BLOB_NAME} ]; then
        export JETSON_NANO_SD_BLOB_NAME=jetson.img
	printf "\e[33mblob name is not specified,, use predefined (${JETSON_NANO_SD_BLOB_NAME})\e[0m\n"
fi

printf "\e[32mBuild the image ...\n"

# Create the build dir if it does not exists
mkdir -p ${JETSON_BUILD_DIR}

# Download L4T
if [ ! "$(ls -A ${JETSON_BUILD_DIR})" ]; then
        printf "\e[32mDownload L4T... "
        wget -qO- ${bsp} | tar -jxpf - -C ${JETSON_BUILD_DIR}
	rm ${JETSON_BUILD_DIR}/Linux_for_Tegra/rootfs/README.txt
        printf "[OK]\n"
fi

# copy my rootfs to L4T rootfs
cp -rp ${JETSON_ROOTFS_DIR}/*  ${JETSON_BUILD_DIR}/Linux_for_Tegra/rootfs/ > /dev/null

patch ${JETSON_BUILD_DIR}/Linux_for_Tegra/nv_tegra/nv-apply-debs.sh < patches/nv-apply-debs.diff

pushd ${JETSON_BUILD_DIR}/Linux_for_Tegra/ > /dev/null

printf "Extract L4T binaries ... \e[0m\n"
./apply_binaries.sh
printf "\e[32m[OK]\e[0m\n"

if [ ${JETSON_NANO_STORAGE_TYPE} == "emmc" ]; then
        printf "\e[32mDone!\e[0m\n"
        printf "\"emmc\" type pass create image blob stage,, run \"flash_emmc.sh\" next\n"
        exit 0
fi

#----------------------------------------------------------------------------------------------------
# ! this stage not required for jetson nano production kit (emmc), only SD Card image
#----------------------------------------------------------------------------------------------------
pushd ${JETSON_BUILD_DIR}/Linux_for_Tegra/tools

# [USAGE]
# ./jetson-disk-image-creator.sh -o <blob_name> -b <board> -r <revision>
#
# [revision number]
# B00, B01 = 300
# A02 = 200
# A01 = 100
case "${JETSON_NANO_MEMORY_TYPE}" in
    2gb)
        printf "Create image for Jetson nano 2GB board"
        ./jetson-disk-image-creator.sh -o ${JETSON_NANO_SD_BLOB_NAME} -b jetson-nano-2gb-devkit
        printf "OK\n"
        ;;

    4gb)
        revision=${JETSON_NANO_REVISION:=300}
        printf "Create image for Jetson nano board (%s revision)\n" ${revision}
        #printf "/jetson-disk-image-creator.sh -o ${JETSON_NANO_BLOB_NAME} -b ${JETSON_NANO_BOARD_CONFIG} -r ${revision}"
        ./jetson-disk-image-creator.sh -o ${JETSON_NANO_BLOB_NAME} -b ${JETSON_NANO_BOARD_CONFIG} -r ${revision}
        printf "OK\n"
        ;;

    *)
	printf "\e[31mUnknown Jetson nano board memory type\e[0m\n"
	exit 1
        ;;
esac

printf "\e[32mImage created successfully\n"
printf "Image location: ${JETSON_BUILD_DIR}/Linux_for_Tegra/tools/${JETSON_NANO_BLOB_NAME}\n"
