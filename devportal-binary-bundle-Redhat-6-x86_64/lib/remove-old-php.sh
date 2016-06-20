#!/bin/bash

# This script currently isn't included, but we will doubtless have reason to
# use it sooner or later.

case $platform_variant in
  rhel)
    old_php_rpms=$( rpm -qa --queryformat="%{NAME}\n" | grep '^php' | grep -v 'php56u' 2>/dev/null)
    if [[ "$old_php_rpms" != "" ]] ; then
      display "Removing RPMs pertaining to older versions of PHP."
      yum remove -y $old_php_rpms >> $logfile 2>&1
    fi
  suse)
    remove_old_php=0
    trap - ERR
    which_php=$( which php 2>/dev/null )
    register_exception_handlers
    if [[ ! -z $which_php && -x $which_php ]] ; then
      if [[ $opdk_os_major -eq 11 ]] ; then
        minimum_minor=6
      else
        minimum_minor=5
      fi
    	    
      php_version="$( $which_php --version | head -n 1 | cut -d ' ' -f2 )"
      php_version_major="$( echo $php_version | cut -d ' ' -f1 )"
      php_version_minor="$( echo $php_version | cut -d ' ' -f2 )"
      if [[ $php_version_major -lt 5 ]] ; then
        remove_old_php=1
      elif [[ $php_version_minor -lt $minimum_minor ]] ; then
      	remove_old_php=1
      fi
    fi
    if [[ $remove_old_php -eq 1 ]] ; then
      old_php_rpms=$( rpm -qa --queryformat="%{NAME}\n" | grep 'php' 2>/dev/null)
      if [[ "$old_php_rpms" != "" ]] ; then
        display "Removing RPMs pertaining to older versions of PHP."
        zypper remove -y $old_php_rpms >> $logfile 2>&1
      fi      
    fi
esac
