#!/bin/bash

# Expected variables:
#   $logfile
#   $platform_variant

# Configure vhost, keep looping until we get a valid install dir.
is_valid_install_dir=0
while [ $is_valid_install_dir -eq 0 ]; do

  # Let user choose where to put Dev Portal install, but make sure devportal install dir is absolute.
  while [ $is_valid_install_dir -eq 0 ]; do
    prompt_question_text_input "Where should Dev Portal application files be installed?" devportal_install_dir "/var/www/html"
    regex="^/"
    if [[ $devportal_install_dir =~ $regex ]]; then
      is_valid_install_dir=1
    else
      is_valid_install_dir=0
      display_error "Please enter an absolute directory path."
    fi
  done

  # Assume IS_VALID_INSTALL_DIR until find out otherwise.
  is_valid_install_dir=1

  # Assume Dev Portal install dir is not a file unless we find out otherwise.
  is_devportal_install_dir_a_file=0

  # If file location is a file and not a dir
  if [ -f $devportal_install_dir  ]; then
    display_error "Dev Portal application directory path exists and is a file: ${devportal_install_dir}"
    prompt_question_yes_or_no_default_yes "Would you like to delete this file? If you choose 'N', you will be asked to enter a different install directory." delete_devportal_install_file

    # Delete files
    if [[ $delete_devportal_install_file == "y" ]]; then
      rm -rf $devportal_install_dir  >> $logfile 2>&1
    else
      is_valid_install_dir=0
      is_devportal_install_dir_a_file=1
    fi
  fi

  # Create the Dev Portal web dir if it DNE
  if [ -d $devportal_install_dir ] ; then
    display "Dev Portal application directory already exists: ${devportal_install_dir}"
  else
    # Only mkdir if install dir is not a file (will loop again).
    if [ ! -f $devportal_install_dir ]; then
      mkdir --mode=755 -p $devportal_install_dir >> $logfile 2>&1
    fi
  fi

  # See if there are already files in the $devportal_install_dir
  if [ "$(ls -A $devportal_install_dir)" ]; then
      is_devportal_install_dir_empty=0
  else
      is_devportal_install_dir_empty=1
  fi

  # If directory is not empty make user empty it first if install dir is not a file (will loop again).
  if [ $is_devportal_install_dir_empty -eq 0 -a $is_devportal_install_dir_a_file -ne 1 ]; then
    display_error "Dev Portal application directory is not empty: ${devportal_install_dir}"
    prompt_question_yes_or_no_default_yes "Would you like to delete all files in the ${devportal_install_dir} directory? If you choose 'N', you will be asked to enter a different install directory." delete_devportal_files

    # Delete files
    if [[ $delete_devportal_files == "y" ]]; then
      rm -rf $devportal_install_dir  >> $logfile 2>&1
      mkdir --mode=755 -p $devportal_install_dir  >> $logfile 2>&1
    else
      is_valid_install_dir=0
    fi

  fi
done
display "Dev Portal will be installed to: ${devportal_install_dir}."

display "An Apache virtual host will be configured for the Developer Portal."
display ""
display_multiline "You will need to give a valid DNS configured hostname for this server or you will
not be able to connect to the server from any remote system.  If you have not configured
this system with a hostname, use the IP address of the server."
display ""

# Try to get the ip address of this server.
# Barebones CentOS/RHEL 7 don't ship ifconfig; use ip addr instead.
if [[ $platform_variant == 'rhel' && $opdk_os_major -gt 6 ]]; then
  host_ip=`ip addr 2>> $logfile | grep "inet " | grep -v "127\.0\.0\.1" | head -n 1 | sed -E "s/^ +//g" | cut -d " " -f2 | cut -d "/" -f1`
else
  host_ip=`ifconfig 2>> $logfile | grep "inet addr" | grep -v "127\.0\.0\.1" | head -n 1 | cut -d ":" -f2 | cut -d " " -f1`
fi
while [[ -z $portal_hostname ]] ; do
  prompt_question_text_input "What hostname or IP should be associated with the Dev Portal" portal_hostname $host_ip
done

trap - ERR
is_ip=$( echo $portal_hostname | egrep -c "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" )
register_exception_handlers

case $platform_variant in
  rhel)
    httpdconf_dir=/etc/httpd/conf
    vhosts_dir=/etc/httpd/conf/vhosts
    local_vhosts_dir=conf/vhosts
    apache_service_name=httpd
    ;;
  suse)
    httpdconf_dir=/etc/apache2
    vhosts_dir=/etc/apache2/vhosts.d
    local_vhosts_dir=$vhosts_dir
    apache_service_name=apache2
    ;;
  debian)
    httpdconf_dir=/etc/apache2
    vhosts_dir=/etc/apache2/sites-available
    apache_service_name=apache2
    ;;
esac

if [[ $platform_variant == 'rhel' || $platform_variant == 'suse' ]] ; then
  if [[ ! -d $vhosts_dir ]] ; then
    display "Creating vhosts directory: ${vhosts_dir}..."
    mkdir -p $vhosts_dir   >> $logfile 2>&1
  fi
  if [[ $( cat ${httpdconf_dir}/httpd.conf | grep "^Include" | grep -c vhosts ) -eq 0 ]]; then
    display
    cp ${httpdconf_dir}/httpd.conf ${httpdconf_dir}/httpd.conf.orig   >> $logfile 2>&1
    (
      echo "# Include ${vhosts_dir}/*.conf for Dev Portal virtual hosts"
      echo "Include ${local_vhosts_dir}/*.conf"
    ) >> ${httpdconf_dir}/httpd.conf
  fi
fi

if [[ $is_ip -eq 0 && $( grep -c ^ServerName ${httpdconf_dir}/httpd.conf ) -eq 0 ]] ; then
  echo "ServerName ${portal_hostname}" >> ${httpdconf_dir}/httpd.conf
fi

(
  echo "<VirtualHost *:80>"
  if [[ $is_ip -eq 0 ]] ; then
    echo " ServerName ${portal_hostname}"
  fi
  echo " DocumentRoot \"${devportal_install_dir}\""
  echo " <Directory \"${devportal_install_dir}\">"
  echo "   Options Indexes FollowSymLinks MultiViews"
  echo "   AllowOverride All"
  echo "   Order allow,deny"
  echo "   Allow from all"
  echo " </Directory>"
  echo " ErrorLog /var/log/${apache_service_name}/devportal_error.log"
  echo " LogLevel warn"
  echo " CustomLog /var/log/${apache_service_name}/devportal_access.log combined"
  echo "</VirtualHost>"
) > ${vhosts_dir}/devportal.conf 2>> $logfile

# On SuSE, we must explicitly enable required Apache modules
if [[ $platform_variant == 'suse' ]] ; then
  apache_modules=$(grep "^APACHE_MODULES=" /etc/sysconfig/apache2)
  if [[ $( echo $apache_modules | grep -c rewrite ) -eq 0 ]] ; then
    display "Enabling mod_rewrite"
    a2enmod rewrite >> $logfile 2>&1
  fi
  # mod_access_compat is needed or you get "Invalid command 'Order'" in vhosts file.
  if [[ $( echo $apache_modules | grep -c mod_access_compat ) -eq 0 ]] ; then
    display "Enabling mod_access_compat"
    a2enmod mod_access_compat >> $logfile 2>&1
  fi
  # authz_host is needed or you get "Invalid command 'Order'" in vhosts file.
  if [[ $( echo $apache_modules | grep -c authz_host ) -eq 0 ]] ; then
    display "Enabling authz_host"
    a2enmod authz_host >> $logfile 2>&1
  fi
  # mod_php is required for Dev Portal.
  if [[ -f /usr/lib64/apache2/mod_php5.so && $( echo $apache_modules | grep -c mod_php5 ) -eq 0 ]] ; then
    display "Enabling mod_php5"
    a2enmod mod_php5 >> $logfile 2>&1
  fi
fi
if [[ $platform_variant == 'debian' ]] ; then
  if [[ -h /etc/apache2/sites-enabled/devportal.conf ]] ; then
    ln -s /etc/apache2/sites-available/devportal.conf /etc/apache2/sites-enabled/devportal.conf
  fi
  # If no hostname was given, remove configured default site configuration so dev
  # portal will be the default site.
  if [[ $is_ip -eq 1 && -h /etc/apache2/sites-enabled/000-default.conf ]] ; then
    rm /etc/apache2/sites-enabled/000-default.conf
  fi
fi

display "Making sure Apache runs at startup"
case $platform_variant in
  rhel)
    chkconfig --level 35 httpd on >> $logfile 2>&1
    ;;
  suse)
    chkconfig apache2 35 >> $logfile 2>&1
    ;;
  debian)
    update-rc.d apache2 defaults >> $logfile 2>&1
    ;;
esac

if [[ $( service $apache_service_name status | grep -c 'stopped' ) -eq 1 ]] ; then
  display "Restarting Apache..."   >> $logfile 2>&1
  service $apache_service_name start >> $logfile 2>&1
else
  display "Starting Apache..."
  service $apache_service_name restart >> $logfile 2>&1
fi

if [[ $is_ip -eq 0 && $(grep -c "${portal_hostname}" /etc/hosts) -eq 0 ]] ; then
  display "Adding ${portal_hostname} to /etc/hosts"
  echo "127.0.0.1 ${portal_hostname}" >> /etc/hosts
fi

webroot=$devportal_install_dir
