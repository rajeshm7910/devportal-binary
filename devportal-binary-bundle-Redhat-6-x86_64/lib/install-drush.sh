#!/bin/bash

drush_version=7.1.0
drush_home=/usr/local/share/drush

trap - ERR
drush_exe=$( which drush 2>/dev/null )
# It's possible that drush8 was installed as a phar
if [[ -z $drush_exe ]] ; then
  drush_exe=$( which drush.phar 2>/dev/null )
fi
register_exception_handlers

drush_patched=0
php_version_status=$( php -r "echo version_compare(PHP_VERSION, '5.3.3');" )

if [[ -z $drush_exe ]] ; then
  display "Installing drush to ${drush_home}..."
  curl -LkSs -o ${temp_dir}/drush.tar.gz https://codeload.github.com/drush-ops/drush/tar.gz/${drush_version} >> $logfile 2>&1
  err=$?
  if [[ $err -ne 0 ]] ; then
    display_error "curl error code: $err while running the following command:"
    display_error "  curl -LkSs -o ${temp_dir}/drush.tar.gz https://codeload.github.com/drush-ops/drush/tar.gz/${drush_version}"
    display "Make sure your system is properly networked and run the installer again."
    exit
  fi
  tar -C $( dirname $drush_home ) -xzf ${temp_dir}/drush.tar.gz
  [[ -d $drush_home ]] && rm -rf $drush_home
  mv $( dirname $drush_home )/drush-${drush_version} $drush_home

  # If PHP is too old, patch drush 7 so it won't fail.
  if [[ $php_version_status -lt 1 ]]; then
    cwd=$( pwd )
    cd $drush_home
    patch -p1 < ${script_path}/resources/drush-php533.patch >> $logfile 2>&1
    drush_patched=1
    cd $cwd
  fi

  $composer_exe install --no-dev --no-progress --no-ansi --working-dir=$drush_home >> $logfile 2>&1
  err=$?
  if [[ $err -ne 0 ]] ; then
    display_error "composer error code: $err while running the following command:"
    display_error "  composer install --no-dev --no-progress --no-ansi --working-dir=$drush_home"
    display "Make sure your system is properly networked and run the installer again."
    exit
  fi
  ln -s $drush_home/drush /usr/local/bin/drush
  display "Finished installing drush."
  drush_exe=/usr/local/bin/drush
fi

# If we have an ancient version of PHP and drush version of 7,
# patch drush to prevent it from erroring out. This should only
# happen for CentOS 6 and RHEL 6.
if [[ $drush_patched -eq 0 && $php_version_status -lt 1 ]]; then
  drush_major_version=$( $drush_exe --version | sed -r 's/.*: +//' | head -n 1 | cut -d "." -f1 )
  if [[ $drush_major_version -eq 7 ]]; then
    # Try to resolve the path the drush exe points to.
    # Generally this will be /usr/local/share/drush/drush.
    drush_path=$drush_exe
    if [[ -h $drush_exe ]] ; then
      drush_path=$( readlink -f $drush_exe )
    fi
    drush_path=$( dirname $drush_path )
    drush_inc="${drush_path}/includes/drush.inc"
    if [[ -f $drush_inc ]]; then
      # Don't try to re-patch an already-patched drush.
      if [[ $( grep -c "return \\\$reflectionClass->newInstance" $drush_inc ) -gt 0 ]]; then
        display "Patching drush 7 to run on PHP 5.3.3."
        cwd=$( pwd )
        cd $drush_path
        patch -p1 < ${script_path}/resources/drush-php533.patch  >> $logfile 2>&1
        cd $cwd
      fi
    fi
    # TODO: Warn user if we couldn't find drush.inc to patch.
  fi
fi

# Enable drush rr if it is not already present.
if [[ $( $drush_exe help | grep -c registry-rebuild ) -eq 0 ]]; then
  display "Installing registry-rebuild drush task..."
  $drush_exe dl registry_rebuild >> $logfile 2>&1
fi

