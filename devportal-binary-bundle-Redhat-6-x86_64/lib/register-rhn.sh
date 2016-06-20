#!/bin/bash

# Register on RHN if running on Red Hat and configure repos.
# Expected vars:
#   $opdk_distro
#   $opdk_os_major
#   $opdk_os_minor

# Ensure RHEL is registered with RHN.
registration_type="none"
if [[ -f /etc/sysconfig/rhn/systemid ]] ; then
  registration_type="legacy"
elif [[ -f /etc/yum.repos.d/redhat.repo ]] ; then
  sslclientcert=`grep sslclientcert /etc/yum.repos.d/redhat.repo | head -n 1 | cut -d "=" -f2 | tr -d " "`
  if [[ ! -z $sslclientcert && -f $sslclientcert ]] ; then
    registration_type="subscription-manager"
  fi
fi

if [[ $registration_type == 'none' ]] ; then
  display_multiline "
--------------------------------------------------------------------------------
WARNING: Your system is not registered with Red Hat.

You must register your system with Red Hat in order to use offical Red Hat Yum
repositories.  If you do not register your system, some needed RPM packages may
not be available which will cause this installer to fail.
"
  prompt_question_yes_or_no_default_yes "Do you want to register with Red Hat?" register_rhn

  if [[ $register_rhn = 'n' ]] ; then
    # Exit from this script.
    return 0
  fi
  rhn_user=
  rhn_pass=
  while [[ -z $rhn_user ]] ; do
    prompt_question_text_input "RHN username" rhn_user
  done
  while [[ -z $rhn_pass ]] ; do
    prompt_question_password_input "RHN password" rhn_pass
  done
  trap - ERR
  subscription-manager register --username="${rhn_user}" --password="${rhn_pass}" --auto-attach >> $logfile 2>&1
  rhn_registered=$?
  register_exception_handlers
  if [[ $rhn_registered -ne 0 ]] ; then
    display_error "Invalid credentials"
    display_error "The Red Hat Network credentials you entered were not correct, or there are licensing issues with your account."
    exit 1
  fi
  display "Registration succeeded."
  registration_type="subscription-manager"
elif [[ $registration_type == 'legacy' && `rhn-channel -l | grep -c 'server-optional'` -eq 0 ]] ; then

  display_multiline "
--------------------------------------------------------------------------------
WARNING: Your system does not have the Red Hat server-optional channel
         registered.

You will need to supply your Redhat username and password to register the
server-optional channel.

If you do not register the server-optional channel, some needed RPM packages may
not be available which will cause this installer to fail.
"
  prompt_question_yes_or_no_default_yes "Do you want to supply your Red Hat username/password in order to register the server-optional channel?" register_server_optional_ch

  if [[ $register_server_optional_ch = 'n' ]] ; then
    # Exit from this script.
    return 0
  fi

  display "Registering to server-optional channel"
  rhn_user=
  rhn_pass=
  while [[ -z $rhn_user ]] ; do
    prompt_question_text_input "RHN username" rhn_user
  done
  while [[ -z $rhn_pass ]] ; do
    prompt_question_password_input "RHN password" rhn_pass
  done
  server_opt_channel=`rhn-channel -L --user=${rhn_user} --password=${rhn_pass} | grep server-optional | sort | head -n 1`
  if [[ -z $server_opt_channel ]] ; then
    display_error "No server-optional channel found."
    display_error "Unable to determine name of the server-optional channel."
    display_error "Please ensure that you are correctly registered with the Red Hat Network, then re-run this script."
    exit 1
  fi
  trap - ERR
  rhn-channel --add --channel=$server_opt_channel --user=${rhn_user} --password=${rhn_pass} >> $logfile 2>&1
  registered_channel=$?
  register_exception_handlers

  if [[ $registered_channel -ne 0 ]] ; then
    display_error "Cannot register to channel $server_opt_channel "
    display_error "Unable to register to the following channel:"
    display_error " ${server_opt_channel}"
    display_error "This may require manually registering the channel using the rhn-channel "
    display_error "command. When you have successfully registered this channel, you may "
    display_error "re-run this script."
    exit 1
  fi
  display "Server-optional channel registered."
fi # registration_type is legacy

# Register server-optional channel for non-legacy customers.
if [[ $registration_type == 'subscription-manager' ]] ; then
  serv_opt_enabled=0
  if [[ -f /etc/yum.repos.d/redhat.repo ]]; then
    serv_opt_enabled=$( sed -n /\\[rhel-${opdk_os_major}-server-optional-rpms\\]/,/^$/p /etc/yum.repos.d/redhat.repo | egrep -c "enabled\\s*=\\s*1" )
  fi
  if [[ $serv_opt_enabled -gt 0 ]]; then
    display "Already registered to server-optional channel"
  else
    display "Registering to server-optional channel"
    if [[ $opdk_os_major -ge 7 ]] ; then
      # use subscription-manager for RHEL 7+.
      repo_command="subscription-manager repos"
    else
      # use yum-config-manager for distros before RHEL 7.
      trap - ERR
      ycm_path=`which yum-config-manager 2>/dev/null`
      register_exception_handlers
      if [[ -z $ycm_path ]] ; then
        display "Installing yum-config-manager from package yum-utils"
        trap - ERR
        yum install -y yum-utils >> $logfile 2>&1
        success=$?
        register_exception_handlers
        if [[ $success -ne 0 ]] ; then
	  display_error "Install yum-utils failed"
	  display_error "Failed to install yum-utils RPM."
	  exit 1
        fi
        display "yum-config-manager installed."
      fi
      repo_command="yum-config-manager"
    fi
    trap - ERR
    $repo_command --enable rhel-${opdk_os_major}-server-optional-rpms 2>&1 | tee -a ${logfile}
    err=$?
    register_exception_handlers
    if [ $err -ne 0 ] ; then
      display_error "${repo_command} --enable rhel-${opdk_os_major}-server-optional-rpms failed"
      display_error "Failed to enable the server-optional channel."
      exit 1
    fi
    display "Server-optional channel registered."
  fi
fi

