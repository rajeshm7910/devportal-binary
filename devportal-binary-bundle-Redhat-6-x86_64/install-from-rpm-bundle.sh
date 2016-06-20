#!/bin/bash

###
# This is the start script for a non-networked install.
##

if [[ $( whoami ) != 'root' ]] ; then
  echo "$0 must be run as root (or run via sudo)."
  exit 1
fi

has_network=0
drush_home=/usr/local/share/drush

# Get directory this script is running in and put it in SCRIPT_PATH
source="${BASH_SOURCE[0]}"
while [ -h "$source" ]; do
  # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$source" )" && pwd )"
  source="$(readlink "$source")"
  # if $SOURCE was a relative symlink, we need to resolve it relative to the
  # path where the symlink file was located
  [[ $source != /* ]] && source="$DIR/$source"
done
script_path="$( cd -P "$( dirname "$source" )" && pwd )"

repo_path="${script_path}/devportal-repo"

# Load command line args script
source ${script_path}/lib/bash_cmd_args.sh

# Load function library
source ${script_path}/lib/bash_toolkit.sh

script_initialize

# Get OS and version information.
source ${script_path}/lib/detect-os.sh

# -----------------------------------------------------
# Starting Installation
# -----------------------------------------------------

display_h1 "Starting non-networked installation ${script_rundate}"
os_info="$( cat $release_file | head -n 1 )"
display "${os_info}"

# Configure the repo
display_h1 "Step 1: Configure local package repository"
case $platform_variant in
  rhel)
    if [[ -f /etc/yum.repos.d/devportal.repo ]] ; then
      echo "The Dev Portal repo is already configured... "
    else
      echo "Configuring Dev Portal repo."
      (
        echo "[devportal]"
        echo "name=Dev Portal Installation Repository"
        echo "baseurl=file://${repo_path}"
        echo "enabled=1"
      ) > /etc/yum.repos.d/devportal.repo
      # yum clean all fails if enabled=0 and no other repos are available
      yum clean all
      sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/devportal.repo
    fi
    ;;
  suse)
    repos=`zypper repos | tail -n +3 | cut -d "|" -f3`
    if [[ $(echo "${repos}" | grep -c devportal) -eq 1 ]]; then
      echo "The Dev Portal repo is already configured... "
    else
      echo "Configuring Dev Portal repo."
      zypper addrepo --no-gpgcheck ${repo_path} devportal
    fi
    ;;
  debian)
    if [[ $( grep -c "^deb file:${repo_path}" /etc/apt/sources.list ) -gt 1 ]] ; then
      echo "The Dev Portal repo is already configured... "
    else
      echo "Configuring Dev Portal repo."
      (
        echo
        echo "## Software bundled expressly for Dev Portal installation"
        echo "deb file:${repo_path} ./"
      ) >> /etc/apt/sources.list
    fi
    ;;
esac

display_h1 "Step 2: Install Apache and PHP Software Packages"
source ${script_path}/lib/install-required-pkgs.sh
source ${script_path}/lib/configure-php.sh

display_h1 "Step 3: Install drush"
[[ -d $drush_home ]] && rm -rf $drush_home
[[ -f /usr/local/bin/drush || -h /usr/local/bin/drush ]] && rm -f /usr/local/bin/drush
mkdir -p $drush_home
tar -C $drush_home -xf ${script_path}/drush.tar >> $logfile 2>&1
ln -s ${drush_home}/drush /usr/local/bin/drush >> $logfile 2>&1

display_h1 "Step 4: Install and Configure Database"
source ${script_path}/lib/install-mysqld.sh

display_h1 "Step 5: Configure Apache Web Server"
source ${script_path}/lib/configure-apache.sh

display_h1 "Step 6: Installing Dev Portal Drupal files"
[[ -d $devportal_install_dir ]] && rm -rf $devportal_install_dir
cp -r ${script_path}/devportal-webroot $devportal_install_dir >> $logfile 2>&1
cp -r ${script_path}/devportal-webroot/.[!.]* $devportal_install_dir >> $logfile 2>&1

display "Setting Dev Portal permissions..."
webroot=${devportal_install_dir}
is_installer_running=1
source ${script_path}/lib/configure-apache-webroot-permissions.sh
# Make sure settings.php is writable
chmod 660 ${webroot}/sites/default/settings.php >> $logfile 2>&1

display_h1 "Step 7: Modifying security settings to allow incoming HTTP connections."
source ${script_path}/lib/configure-security.sh

display_multiline "
--------------------------------------------------------------------------------
Dev Portal Installation Complete
--------------------------------------------------------------------------------
You are ready to configure your Dev Portal by
going to the following URL using your local web browser:

http://${portal_hostname}

Keep the following information for the rest of the install and for future
reference.

Apache Configuration
--------------------
Dev Portal URL: http://${portal_hostname}
Dev Portal web root: ${devportal_install_dir}

Database Configuration
----------------------
Dev Portal database hostname: ${db_host}
Dev Portal database port: ${db_port}
Dev Portal database name: ${db_name}
Dev Portal database user: ${db_user}
Dev Portal database password: ******* (not shown)

--------------------------------------------------------------------------------
"

