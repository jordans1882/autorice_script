#!/bin/bash
# {{{ Header
# Author: Jordan Schupbach
# Filename: autorice.sh
# Date Initialized: August 2, 2018
# Date Modified: August 2, 2018
# Description: 
#   A script that configures my or some custom version of my system
# }}} Header

# {{{ Linux
# {{{ Check if on linux
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  HASLINUX=TRUE
# }}} Check if on linux
  # {{{ Check for permisions
  if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
  fi
  # }}} Check for permisions
  # {{{ Obtain Linux Distrobution
  OSNAMESTRING="$(cat /etc/os-release | grep -m 1 'NAME')"
  echo $OSNAMESTRING
  ARCH="Arch"
  UBUNTU="Ubuntu"
  # }}} Obtain Linux Distrobution

  # Distrobution specific setup:
  # {{{ Ubuntu
    if [ -z "${OSNAMESTRING##*$UBUNTU*}" ] ;then
      echo "I'm sorry, but you are working on an inferior linux distrobution."
    fi
  # }}} Ubuntu
  # {{{ Arch Linux
    if [ -z "${OSNAMESTRING##*$ARCH*}" ] ;then
      echo "You have Arch Linux! Lucky you and smart choice!"
      sudo pacman -S dialog
    fi
  # }}} Arch Linux
fi
# }}} Linux

# {{{ Other Systems
# TODO: Windows, Mac, ...
# elif [[ "$OSTYPE" == "darwin"* ]]; then
#         # Mac OSX
# elif [[ "$OSTYPE" == "cygwin" ]]; then
#         # POSIX compatibility layer and Linux environment emulation for Windows
# elif [[ "$OSTYPE" == "msys" ]]; then
#         # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
# elif [[ "$OSTYPE" == "win32" ]]; then
#         # I'm not sure this can happen.
# elif [[ "$OSTYPE" == "freebsd"* ]]; then
#         # ...
# else
#         # Unknown.
# }}} Other Systems

# {{{ Vim modelines
# vim: set foldmethod=marker
# }}} Vim modelines
