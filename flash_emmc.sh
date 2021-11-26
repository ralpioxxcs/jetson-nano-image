#! /bin/bash

#
# Author: ralpioxxcs
#

# @brief : Flash to jetson nano emmc board 
# @env :
#   * JETSON_BUILD_DIR - build output directory

set -e

RED="\e[31m"
GREEN="\e[32m"
BOLDGREEN="\e[1;32m"
ITALICRED="\e[3;31m"
ENDCOLOR="\e[0m"

main() {

printf "${BOLDGREEN}- - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n${ENDCOLOR}"
printf "${BOLDGREEN}Flash eMMC image to jetson-nano-eMMC production board.\n${ENDCOLOR}"
printf "${BOLDGREEN}- - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n${ENDCOLOR}"

if [ "x$(whoami)" != "xroot" ]; then
	printf "\e[31mThis script requires root privilege!\e[0m\n"
	confirm_exit
fi

check_device

flashing ${JETSON_BUILD_DIR}

}


function confirm_exit() {
	read -n1 -p "Press any key to exit."
	exit
}

function check_device() {
  # check whether jetson nano device is recovery mode or not
  number=`lsusb | awk '/NVidia Corp./ {print $6}' | cut -d ':' -f 2`
  module_number="7f21" # jetson nano production module number
  if [ -z "${number}" ]; then
    printf "\e[31mAny device is not detected\e[0m\n"
    confirm_exit
  fi
  if [ "${number}" != "${module_number}" ]; then
    printf "\e[31mPlease ensure jetson nano in FCM(Force Recovry Mode)\e[0m\n"
    confirm_exit
  fi
}

function flashing() {
  if [ ! "$(ls -A ${JETSON_BUILD_DIR})" ]; then
	  printf "\e[31mNo L4T Directory found in \"${JETSON_ROOTFS_DIR}\"\e[0m\n"
    confirm_exit
  fi

  local l4t_dir=${JETSON_BUILD_DIR}/Linux_for_Tegra
  pushd ${l4t_dir}

  # Flashing
  local board=jetson-nano-emmc # device
  local partition=mmcblk0p1 # eMMC partition
  sudo ./flash.sh ${board} ${partition}
  if [ $? -eq 0 ]; then
    printf "\e[32mFlashing is completed successfuly\e[0m\n"
  else
    printf "\e[31mFailed to flashing to device\e[0m\n"
  fi

  popd

  confirm_exit
}

main "$@"; exit
