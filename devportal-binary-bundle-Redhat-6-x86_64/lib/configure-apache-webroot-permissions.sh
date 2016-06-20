#!/bin/sh
# Expected vars:
#   $is_installer_running: set to 1 if you are calling from installer
#     to change displayed information to user.
#   $logfile: the location to a file to write logs to, or /dev/null.
#   $platform_variant

case $platform_variant in
  rhel)
    devportal_group=$(grep "^Group" /etc/httpd/conf/httpd.conf | head -n 1 | cut -d " " -f2)
    ;;
  suse)
    devportal_group="www"
    if [[ -f /etc/apache2/uid.conf ]] ; then
      devportal_group=$( grep Group /etc/apache2/uid.conf | cut -d " " -f2 )
    fi
    ;;
  debian)
    devportal_group="www-data"
    if [[ -f /etc/apache2/envvars ]] ; then
      devportal_group=$( grep APACHE_RUN_GROUP /etc/apache2/envvars | cut -d "=" -f2 )
    fi
    ;;
esac

# Make sure files are owned by Apache and permissions are properly set
if [[ -z $is_installer_running ]] ; then
  display_multiline "
  This script will modify the Dev Portal code to be read only for the
  Apache HTTP Server for security.

  For production systems, it is highly recommended
  to have a user added to the system other than root which will own
  the files in the web root of the Dev Portal installation.

  "
else
  display_multiline "
  For security reasons, the Dev Portal code should be read only for
  the Apache HTTP Server.  For production systems, it is highly recommended
  to have a user added to the system other than root which will own
  the files in the web root: ${webroot}

  If you have not created a user in the system, you can have root own
  the files in webroot for now, and run fix-webroot-permissions.sh located
  in the tools directory at a later time.

  "
fi

if [[ -z ${webroot} ]] ; then
  prompt_question_text_input "What is the location of the webroot of the Dev Portal install? " webroot "/var/www/html"
fi

# Webroot should by default owned by user running this script.
is_valid_user=0
script_user=$( whoami )
# Make sure user is valid on this system by checking against /etc/passwd
until [[ $is_valid_user -ne 0 ]] ; do
  prompt_question_text_input "What user should own the devportal files in the webroot? " devportal_owner $script_user
  is_valid_user=$( grep -c "^${devportal_owner}:" /etc/passwd )
  if [[ $is_valid_user -eq 0 ]]; then
    echo "${devportal_owner} is not a valid user on this system. Please try again."
  fi
done

display "Setting ownership of ${webroot} to ${devportal_owner} user and ${devportal_group} group..."
chown -R ${devportal_owner}:${devportal_group} $webroot
display_nonewline "Setting file and directory permissions of ${webroot}..."
find ${webroot} -type d -exec chmod u=rwx,g=rx,o= '{}' \; >> $logfile 2>&1
find ${webroot} -type f -exec chmod u=rw,g=r,o= '{}' \; >> $logfile 2>&1
find ${webroot}/sites -type d -name files -exec chmod ug=rwx,o= '{}' \; >> $logfile 2>&1
for x in  ${webroot}/sites/*/files; do
  find ${x} -type d -exec chmod ug=rwx,o= '{}' \; >> $logfile 2>&1
  find ${x} -type f -exec chmod ug=rw,o= '{}' \; >> $logfile 2>&1
done
find ${webroot}/sites -type d -name private -exec chmod ug=rwx,o= '{}' \; >> $logfile 2>&1
# TODO: we are setting all permissions at the end, this is probably not needed.
chmod 660 ${webroot}/sites/default/settings.php >> $logfile 2>&1
chmod 770 ${webroot}/sites/default/tmp >> $logfile 2>&1
display "done."