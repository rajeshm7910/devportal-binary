#!/bin/bash

if [[ $opdk_os_minor -gt 0 ]] ; then
  dvd_media_id="SLES-${opdk_os_major}-SP${opdk_os_minor}"
  pool_repo="SLES${opdk_os_major}-SP${opdk_os_minor}-Pool"
else
  dvd_media_id="SLES-${opdk_os_major}"
  pool_repo="SLES${opdk_os_major}-Pool"
fi

repo_list=$(zypper lr -u | tail -n +3 | cut -d "|" -f3)

# Need to turn off error trapping for this zypper line.
trap - ERR
has_base_repo=0
if [[ $( egrep -c "${dvd_media_id}.+iso9660" /etc/mtab ) -gt 0 ]] ; then
  has_base_repo=$( zypper lr -u | grep "cd:///" | cut -d "|" -f2 | grep -c "SUSE-Linux-Enterprise" )
fi
if [[ $has_base_repo -eq 0 ]] ; then
  has_base_repo=$( echo "${repo_list}" | grep -c $pool_repo )
fi
register_exception_handlers


if [[ $has_base_repo -eq 0 ]] ; then
  display_error "You must have the the ${pool_repo} repository in your repo list."
  if [[ -z "$repo_list" ]] ; then
    display_error "You have no repositories configured at this time."
  else
    echo "Here are your current repositories:"
    echo
    echo "$repo_list"
  fi
  echo
  display_error "Please resolve this issue, then re-run the script."
  exit 1
fi

if [[ $opdk_os_major -gt 11 ]] ; then
  trap - ERR
  has_web_scripting=$(echo "${repo_list}" | grep -c "SLE-Module-Web-Scripting${opdk_os_major}-Pool")
  has_sdk=$(echo "${repo_list}" | grep -c "SLE-SDK${opdk_os_major}-Pool")
  register_exception_handlers

  if [[ $has_web_scripting -eq 0 || $has_sdk -eq 0 ]]; then
    display_error "One or more required add-on products are not registered."
    if [[ $has_web_scripting -eq 0 ]] ; then
      display_error "    Web and Scripting Module"
    fi
    if [[ $has_sdk -eq 0 ]] ; then
      display_error "    SUSE Linux Enterprise Software Development Kit ${opdk_os_major}"
    fi
    display_multiline "
You can enable these products by running YaST.

When these products have been successfully added, you can re-run this
script.

NOTE: Your system may need to be registered in order to install these
packages.  You can check if your system is registered by using YaST or the
following command:
  SUSEConnect --status-text
"
    exit 1
  fi
fi

