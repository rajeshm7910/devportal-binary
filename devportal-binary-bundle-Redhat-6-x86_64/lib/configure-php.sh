#!/bin/bash

# expected vars:
#   $platform_variant

phpmemory_limit=512M

# Get the php_ini_paths and apc_ini.
case $platform_variant in
  rhel)
    php_ini_paths=/etc
    apc_ini=/etc/php.d/apc.ini
    if [[ ! -f $apc_ini ]]; then
      apc_ini=/etc/php.d/apcu.ini
      # The following applies to PHP 5.6
      if [[ ! -f $apc_ini ]]; then
        apc_ini=/etc/php.d/40-apcu.ini
      fi
    fi
    ;;
  suse)
    php_ini_paths="/etc/php5/apache2 /etc/php5/cli"
    apc_ini=/etc/php5/conf.d/apc.ini
    # The following applies to PHP 5.6
    if [[ ! -f $apc_ini ]] ; then
      apc_ini=/etc/php5/conf.d/apcu.ini
    fi
    ;;
  debian)
    php_ini_paths="/etc/php5/apache2 /etc/php5/cli"
    apc_ini=
    ;;
esac

# Get the timezone from the OS.
if [[ $platform_variant == 'debian' ]] ; then
  if [[ -f /etc/timezone ]] ; then
    php_timezone=$( cat /etc/timezone )
  fi
elif [[ $platform_variant == 'suse' ]] ; then
  # On SUSE, it is: TIMEZONE="America/Los_Angeles"
  if [[ -f /etc/sysconfig/clock ]] ; then
    php_timezone=$( grep '^TIMEZONE=' /etc/sysconfig/clock | cut -d '"' -f2 )
  fi
elif [[ $platform_variant == 'rhel' && $opdk_os_major -eq 7 ]] ; then
  # On RHEL7/CentOS7, use the timedatectl command
  # Timezone may or may not have a space in it.
  php_timezone=$( timedatectl | egrep "Time ?zone" | cut -d ":" -f2 | cut -d " " -f2 )
else
  if [[ -f /etc/sysconfig/clock ]] ; then
    # On Redhat 6, it is: ZONE="America/Los_Angeles"
    php_timezone=$( grep '^ZONE=' /etc/sysconfig/clock | cut -d '"' -f2 )
  fi
fi

if [[ -z $php_timezone ]] ; then
  php_timezone="America/Los_Angeles"
  display_multiline "
--------------------------------------------------------------------------------
Warning: The system's timezone could not be determined. We have selected the
default timezone of ${php_timezone}. If this is not the correct timezone
for your locale, you should edit the date.timezone entry in your php.ini
file(s), which may be found in the following path(s):
"
  for php_ini_path in $php_ini_paths ; do
    echo "${php_ini_path}/php.ini"
  done
  display_multiline "
--------------------------------------------------------------------------------
"
  prompt_question_text_input "Press <ENTER> to continue" ignore
fi

# set php timezone
display "Configuring PHP's timezone to system timezone"
display "Timezone: $php_timezone"

for php_ini_path in $php_ini_paths ; do
  if [[ $( egrep -c "^;?date.timezone\s*=.*" ${php_ini_path}/php.ini ) -eq 1 ]] ; then
    sed -r -i "s@^;?date.timezone\s*=.*@date.timezone = ${php_timezone}@g" ${php_ini_path}/php.ini
  fi
done


for php_ini_path in $php_ini_paths ; do
  # Set max execution time to 90 seconds to enable SmartDocs import to succeed
  met=$( grep '^max_execution_time' ${php_ini_path}/php.ini | tail -n 1 )
  if [[ -z $met ]] ; then
    echo 'max_execution_time = 90' >> ${php_ini_path}/php.ini
  else
    sed -i "s/${met}/max_execution_time = 90/g" ${php_ini_path}/php.ini
  fi
  ml=$( grep '^memory_limit' ${php_ini_path}/php.ini | tail -n 1 )
  if [[ -z $ml ]] ; then
    echo "memory_limit = ${phpmemory_limit}" >> ${php_ini_path}/php.ini
  else
    sed -i "s/^memory_limit = .*/memory_limit = ${phpmemory_limit}/g" ${php_ini_path}/php.ini
  fi
done

if [[ ! -z $apc_ini && -f $apc_ini ]] ; then
  if [[ $platform_variant == 'rhel' ]] ; then
    # Increase default APC memory
    sed -i -E 's/;?apc\.shm_size=[0-9]+M/apc.shm_size=128M/g' $apc_ini
  elif [[ $platform_variant == 'suse' && "$(basename $apc_ini)" == "apcu.ini" ]] ; then
    # SLES 12 comes with 128M of APC memory configured out of the box,
    # so no need to alter that here. However, 11.3 needs help.
    sed -i -E 's/;?apc\.shm_size=[0-9]+M/apc.shm_size=128M/g' $apc_ini
  fi

  # Enable uploadprogress
  if [[ $( egrep -c "^apc.rfc1867 *= *1" $apc_ini ) -eq 0 ]] ; then
    # Remove any existing setting first.
    sed -i '/apc.rfc1867 *=/d' $apc_ini
    echo "; Enable upload progress for Drupal via APC" >> $apc_ini
    echo "apc.rfc1867 = 1" >> $apc_ini
  fi
fi


