#!/bin/bash

####
# Get OS and version information.
#
# This script will set the following vars:
#   platform_variant: The variant of Linux: rhel, oracle, suse, SLE or debian
#   opdk_distro: The distribution, which can be CentOS, Redhat, Oracle,
#                openSUSE or SLE
#   opdk_os_major: Major Linux version, such as 6 for RedHat 6.5
#   opdk_os_minor: Minor Linux version, such as 5 for RedHat 6.5
#   release_file: The file w/OS information
#

if [[ `uname -a | grep -c x86_64` -eq 1 ]] ; then
  opdk_platform=x86_64
else
  display_error "Processors other than x86_64 are not supported."
  exit 1
fi

if [[ -f /etc/redhat-release ]] ; then
  release_file=/etc/redhat-release
  platform_variant=rhel
  [[ `grep CentOS /etc/redhat-release` ]] && opdk_distro=CentOS || opdk_distro=Redhat
  opdk_os_major=`cat /etc/redhat-release | sed -E 's:^.* release ([0-9]).*$:\1:'`
  opdk_os_minor=`cat /etc/redhat-release | sed -E 's:^.* release [0-9]+\.([0-9]+).*$:\1:'`
  # Oracle Linux is built on top of RedHat.
  if [[ -f /etc/oracle-release ]] ; then
    release_file=/etc/oracle-release
    opdk_distro=Oracle
  fi
  if [[ $opdk_os_major -lt 7 ]] ; then
    if [[ $opdk_os_major -lt 6 || $opdk_os_minor -lt 5 ]] ; then
      display_error "${opdk_distro} older than 6.5 is no longer supported."
      exit 1
    fi
  fi
elif [[ -f /etc/SuSE-release ]] ; then
  release_file=/etc/SuSE-release
  platform_variant=suse
  opdk_os_major=`egrep ^VERSION /etc/SuSE-release | cut -d " " -f3`
  [[ `grep openSUSE /etc/SuSE-release` ]] && opdk_distro=openSUSE || opdk_distro=SLE
  if [[ $opdk_distro == 'openSUSE' ]]; then
    opdk_os_minor=`echo $opdk_os_major | cut -d. -f2`
    opdk_os_major=`echo $opdk_os_major | cut -d. -f1`
    repo_subdir="${opdk_distro}_${opdk_os_major}.${opdk_os_minor}"
  else
    opdk_os_minor=`egrep ^PATCHLEVEL /etc/SuSE-release | cut -d " " -f3`
    if [[ $opdk_os_minor -eq 0 ]] ; then
      repo_subdir="${opdk_distro}_${opdk_os_major}"
    else
      repo_subdir="${opdk_distro}_${opdk_os_major}_SP${opdk_os_minor}"
    fi
  fi
  if [[ $opdk_os_major -lt 12 ]] ; then
    if [[ $opdk_os_major -lt 11 || $opdk_os_minor -lt 3 ]] ; then
      display_error "${opdk_distro} older than 11.3 is no longer supported."
      exit 1
    fi
  fi
elif [[ -f /etc/os-release ]] ; then
  release_file=/etc/issue.net
  platform_variant=debian
  opdk_distro=$( grep ^NAME= /etc/os-release | cut -d '"' -f2 )
  opdk_os_major=$( grep ^VERSION_ID= /etc/os-release | cut -d '"' -f2 | cut -d. -f1 )
  opdk_os_minor=$( grep ^VERSION_ID= /etc/os-release | cut -d '"' -f2 | cut -d. -f2 )
else
  echo "Cannot determine Linux distribution. Only CentOS, Red Hat, Ubuntu and SuSE are"
  echo "supported."
  exit 1
fi

echo devportal-binary-bundle-${opdk_distro}-${opdk_os_major}-${opdk_platform}
