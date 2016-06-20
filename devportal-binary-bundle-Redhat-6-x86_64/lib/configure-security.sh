#!/bin/bash

# Expected vars:
#   $logfile
#   $devportal_install_dir
#   $platform_variant

display "Modifying firewall rules for HTTP connections..."

case $platform_variant in
  rhel)
    if [[ $opdk_os_major -lt 7 ]]; then
      # Make sure iptables is running.
      if [[ $( service iptables status 2>&1 | grep -c stopped ) -gt 0 ]]; then
        service iptables start >> $logfile 2>&1
      fi
      # Find the first REJECT line. We want to insert our rules right before it.
      reject_line=$( iptables --line -L | grep REJECT | head -n 1 )
      if [[ -z $reject_line ]]; then
        # Anomaly: no REJECT at all! We therefore insert at top of ruleset.
        which_line=1
      else
        # Grab line number from start of line.
        which_line=$( echo "${reject_line}" | cut -d ' ' -f1 )
      fi

      for iptables_port in 22 80 443 ; do
        iptables -I INPUT ${which_line} -p tcp --dport ${iptables_port} -m state --state NEW,ESTABLISHED -j ACCEPT
      done
      # Make sure these settings are saved to file; otherwise they're lost at
      # next reboot.
      service iptables save
      # Make sure iptables service is configured to autostart at boot.
      chkconfig --level 35 iptables on >> $logfile 2>&1
    else
      # RedHat 7/CentOS 7 use firewalld, turn off if it is started.
      if [ "`systemctl is-active firewalld`" == "active" ]; then
        display_error "WARNING: stopping firewalld to allow HTTP connections."
        systemctl stop firewalld >> $logfile 2>&1
      fi
      # RedHat 7/CentOS 7 use firewalld, disable from starting on boot.
      if [ "`systemctl is-enabled firewalld`" == "enabled" ]; then
        display_error "WARNING: disabling firewalld to allow HTTP connections."
        systemctl disable firewalld >> $logfile 2>&1
      fi

    fi

    # -----------------------------------------------------
    # SELinux
    # -----------------------------------------------------

    # TODO: Do not always disable SELinux if enabled.
    is_selinux_enabled=$( getenforce )
    if [[ $is_selinux_enabled != 'Disabled' ]] ; then
      # Temporarily turn off enforcing for now.
      setenforce 0 >> $logfile 2>&1
      # Make sure SELinux is permissive after reboot.
      sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    fi
    ;;

  suse)
    /sbin/SuSEfirewall2 stop
    /sbin/SuSEfirewall2 open EXT TCP 22
    /sbin/SuSEfirewall2 open EXT TCP 80
    /sbin/SuSEfirewall2 open EXT TCP 443
    /sbin/SuSEfirewall2 start
    ;;

  debian)
    if [[ $( ufw status | grep -c inactive ) -eq 1 ]] ; then
      ufw enable
      ufw allow 22
      ufw allow 80
      ufw allow 443
    fi
    ;;
esac

