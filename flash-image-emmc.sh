#! /bin/bash

#
# Author: ralpioxxcs
#

set -e

RED="\e[31m"
GREEN="\e[32m"
BOLDGREEN="\e[1;32m"
ITALICRED="\e[3;31m"
ENDCOLOR="\e[0m"

function confirm_exit() {
	read -n1 -p "Press any key to exit."
	exit
}

function print_usage() {
  printf "Usage: sudo `basename $0` [folder path] [device conf] [partition]\n"
  printf "e.g.) sudo `basename $0` /home/user/l4t jetson-nano-emmc mmcblk0p1\n"
}

function check_device() {
  # check whether jetson nano device is recovery mode or not
  number=`lsusb | awk '/NVidia Corp./ {print $6}' | cut -d ':' -f 2`
  module_number="7f21" # jetson nano production module number
  if [ -z "${number}" ]; then
    printf "\e[31many device is not detected\e[0m\n"
    confirm_exit
  fi
  if [ "${number}" != "${module_number}" ]; then
    printf "\e[31mplease ensure jetson nano in FCM(Force Recovry Mode)\e[0m\n"
    confirm_exit
  fi
}

function flashing() {
  # $1 : directory of image file
  # $2 : device(t5,spin) string
  echo $1
  echo $2

  if [ -z "$1" ]; then
    printf "${RED}invalid argument${ENDCOLOR}\n"
    confirm_exit
  fi

  local l4t_dir=${HOME}/L4T_32.5/Linux_for_Tegra
  if [ $2 = "t5" ]; then
    image_file_wildcard=t5-emmc*
  elif [ $2 = "spin" ]; then
    image_file_wildcard=spin-emmc*
  else 
    confirm_exit
  fi

  echo ${l4t_dir}
  echo ${image_file_wildcard}

  pushd $1

  # check file condition
  local count=`ls -l ${image_file_wildcard} 2>/dev/null | wc -l`
  if [ ${count} -gt 1 ]; then
    printf "${RED}multiple image file detected. should be only 1 file${ENDCOLOR}\n"
    confirm_exit
  elif [ ${count} -lt 1 ]; then
    printf "${RED}no file detected.\n"
    confirm_exit
  fi

  printf "${BOLDGREEN}unzip image file ...  it might be take time (about 3min)${ENDCOLOR}\n"
  mkdir -p img
  unzip -o ${image_file_wildcard} -d img | pv -l >/dev/null
  pushd img
  mv `ls -p` ${l4t_dir}/bootloader/system.img | pv -l >/dev/null
  popd && rm -rf img

  pushd ${l4t_dir}

  # check image file is exist
  pushd ${l4t_dir}/bootloader
  local img_file=system.img
  if [ ! -f "${img_file}" ]; then
    printf "${RED}image file is not exist!${ENDCOLOR}\n"
    confirm_exit
  fi
  popd

  # Flashing
  local board=jetson-nano-emmc # device
  local partition=mmcblk0p1 # eMMC partition
  # -r : skipping building system.img, use already created system.img
  sudo ./flash.sh -r ${board} ${partition}
  if [ $? -eq 0 ]; then
    printf "\e[32mFlashing is completed successfuly\e[0m\n"
  else
    printf "\e[31mFailed to flashing to device\e[0m\n"
  fi

  popd

  confirm_exit
}

#############################################################################

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  print_usage
  exit 1
fi

printf "${BOLDGREEN}- - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n${ENDCOLOR}"
printf "${BOLDGREEN}Flash eMMC image to jetson-nano-eMMC production board.\n${ENDCOLOR}"
printf "${BOLDGREEN}- - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n${ENDCOLOR}"

if [ "x$(whoami)" != "xroot" ]; then
	printf "\e[31mThis script requires root privilege!\e[0m\n"
	confirm_exit
fi

check_device

while true; do
  printf "Select device which you want to flash\n"
  printf "1) t5\n"
  printf "2) spin\n"
  printf "3) exit\n"
  read ans

  if [ "$ans" != "${ans#[1]}" ]; then
    flashing /home/hong/Desktop/images/t5 t5
  elif [ "$ans" != "${ans#[2]}" ]; then
    flashing /home/hong/Desktop/images/spin spin
  elif [ "$ans" != "${ans#[3]}" ]; then
    exit 1
  else
    printf "${RED}Please answer right number${ENDCOLOR}\n"
  fi
done