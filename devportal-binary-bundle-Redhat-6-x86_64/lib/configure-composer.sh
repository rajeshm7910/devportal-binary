#!/bin/bash

# Ensures composer is installed
trap - ERR
composer_exe="$( which composer 2>/dev/null )" >> $logfile 2>&1
if [[ -z $composer_exe ]] ; then
  composer_exe="$( which composer.phar 2>/dev/null )" >> $logfile 2>&1
fi
register_exception_handlers
if [[ -z $composer_exe ]] ; then
  if [[ ! -d ${temp_dir}/composer ]] ; then
    mkdir -p ${temp_dir}/composer
  fi
  if [[ -f ${temp_dir}/composer/composer.phar ]] ; then
    composer_exe=${temp_dir}/composer/composer.phar
  elif [[ -f ${temp_dir}/composer/composer ]] ; then
    composer_exe=${temp_dir}/composer/composer
  else
    ( curl -o /usr/local/bin/composer https://getcomposer.org/composer.phar && chmod +x /usr/local/bin/composer ) >> $logfile 2>&1
    err=$?
    if [ $err -ne 0 ] ; then
      display_error "curl error code: $err while running the following command: curl -o /usr/local/bin/composer https://getcomposer.org/composer.phar "
      display "Make sure your system is properly networked and run the installer again."
      exit 1
    fi
    chmod +x /usr/local/bin/composer
    composer_exe=/usr/local/bin/composer
  fi

  if [[ ! -x $composer_exe ]] ; then
    chmod +x $composer_exe
  fi
fi

if [[ ! -x $composer_exe ]] ; then
  display_error "${composer_exe} is not executable. Please fix and re-run the script."
  exit 1
fi

