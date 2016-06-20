#!/bin/bash

# Expected vars:
#   $repo_subdir

[[ $opkd_os_major -lt 12 ]] && dl_root=http://download.opensuse.org || dl_root=http://ftp.uni-stuttgart.de/opensuse

display "Validating network is available"
until  curl -X HEAD ${dl_root}/repositories/ --silent --location --fail --head --max-time 5 >/dev/null 2>&1
do
  display_error "Could not reach ${dl_root}/repositories/."
  display_error "Please make sure this server is properly connected to the internet."
  prompt_question_text_input "Press <ENTER> to try again" ignore
done

repos=`zypper repos | tail -n +3 | cut -d "|" -f3`

if [[ $opdk_os_major -lt 12 ]] ; then
  if [[ $(echo "${repos}" | grep -c home_danci1973) -eq 0 ]]; then
    # Needed for php5-APC
    display "Adding needed repo for php5-APC"
    zypper --gpg-auto-import-keys addrepo --no-gpgcheck ${dl_root}/repositories/home:/danci1973/${repo_subdir} home_danci1973  >> $logfile 2>&1
    # Lower priority of repo so standard repos take precedent
    zypper mr -p 70 home_danci1973 >> $logfile 2>&1
  fi
  if [[ $(echo "${repos}" | grep -c oss_suse) -eq 0 ]]; then
    # Needed for dependencies of php5-gd
    display "Adding needed repo for php5-gd dependencies"
    zypper --gpg-auto-import-keys addrepo --no-gpgcheck http://ftp.uni-stuttgart.de/opensuse/distribution/11.4/repo/oss/suse oss_suse >> $logfile 2>&1
    # Lower priority of repo so standard repos take precedent
    zypper mr -p 70 oss_suse >> $logfile 2>&1
  fi
  if [[ $(echo "${repos}" | grep -c devel_tools_scm) -eq 0 ]]; then
    # Needed for git
    display "Adding needed repo for git"
    zypper --gpg-auto-import-keys addrepo --no-gpgcheck ${dl_root}/repositories/devel:/tools:/scm/${repo_subdir} devel_tools_scm >> $logfile 2>&1
    # Lower priority of repo so standard repos take precedent
    zypper mr -p 70 devel_tools_scm >> $logfile 2>&1
  fi
  if [[ $(echo "${repos}" | grep -c devel_languages_perl) -eq 0 ]]; then
    # Needed for git
    display "Adding needed repo for git tools"
    zypper --gpg-auto-import-keys addrepo --no-gpgcheck ${dl_root}/repositories/devel:/languages:/perl/${repo_subdir} devel_languages_perl >> $logfile 2>&1
    # Lower priority of repo so standard repos take precedent
    zypper mr -p 70 devel_languages_perl >> $logfile 2>&1
  fi
### Begin PHP 5.3 section ###
  if [[ $(echo "${repos}" | grep -c home_flacco) -eq 0 ]]; then
    # Needed for php53-sockets, php53-posix
    display "Adding repo for php53-sockets"
    zypper --gpg-auto-import-keys addrepo --no-gpgcheck ${dl_root}/repositories/home:/flacco:/sles/${repo_subdir} home_flacco >> $logfile 2>&1
    # Lower priority of repo so standard repos take precedent
    zypper mr -p 70 home_flacco >> $logfile 2>&1
  fi
###  End PHP 5.3 section  ###
elif [[ $opdk_os_major -eq 12 ]]; then
  if [[ $(echo "${repos}" | grep -c server_php) -eq 0 ]]; then
    # Needed for php5-phar
    display "Adding repo for php5-phar"
    zypper --gpg-auto-import-keys addrepo --no-gpgcheck ${dl_root}/repositories/server:/php/SLE_11 server_php >> $logfile 2>&1
    # Lower priority of repo so standard repos take precedent
    zypper mr -p 70 server_php >> $logfile 2>&1
  fi
  if [[ $(echo "${respo}" | grep -c server_php_extensions) ]] ; then
    # Needed for php5-uploadprogress
    display "Adding repo for php5-uploadprogress"
    zypper --gpg-auto-import-keys addrepo --no-gpgcheck ${dl_root}/repositories/server:/php:/extensions/server_php_SLE_11 server_php_extensions >> $logfile 2>&1
    # Lower priority of repo so standard repos take precedent
    zypper mr -p 70 server_php_extensions >> $logfile 2>&1
  fi
fi

echo "Zypper repositories are properly configured."

