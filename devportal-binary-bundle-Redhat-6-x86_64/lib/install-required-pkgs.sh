#!/bin/bash

# Expected vars:
#   $logfile
#   $has_network
#   $platform_variant

separate_mbstring_install=0

case $platform_variant in
  rhel)
    if [[ $has_network -eq 1 ]]; then
      yum_options=
    else
      yum_options="--disablerepo=* --enablerepo=devportal --nogpgcheck"
    fi
    apache_pkg=httpd
    php_pkg=php
    php_modules="php-pdo php-mysql php-gd php-xml php-process"
    # RHEL/CentOS 7 don't have apc available in the default repos.
    if [[ $opdk_os_major -eq 6 ]]; then
      php_modules="${php_modules} php-pecl-apc"
    fi
    if [[ $opdk_distro == 'Redhat' && $opdk_os_major -eq 6 && $has_network -eq 1 && $registration_type == 'none' ]]; then
      separate_mbstring_install=1
    else
      php_modules="${php_modules} php-mbstring"
    fi
    install_command="yum -y ${yum_options} install"
    ;;
  suse)
    # zypper options are placed before the command.
    zypper_options="--non-interactive"
    # zypper install options are for the install command itself.
    # We need to use --force so the install does not send a non-zero status back.
    zypper_install_options="--auto-agree-with-licenses --force"
    if [[ $has_network -eq 0 ]]; then
      # Do not refresh, it will fail if no network.
      zypper_options="${zypper_options} --no-refresh"
      zypper_install_options="${zypper_install_options} --repo devportal"
    fi
    apache_pkg=apache2
    if [[ $opdk_os_major -lt 12 ]] ; then
      php_pkg=php53
      php_modules="apache2-mod_php53 php53-fileinfo php53-gd php53-gettext \
        php53-mbstring php53-mysql php53-phar php53-posix \
        php53-sockets php53-curl php53-json php53-dom php53-ctype \
        php53-openssl php53-zlib php53-zip php53-pcntl php53-readline php5-APC"
    else
      php_pkg=php5
      # installing the above also installs the following:
      #   php5-ctype php5-dom php5-iconv php5-json php5-pdo php5-sqlite
      #   php5-tokenizer php5-xmlreader php5-xmlwriter
      # php5-phar and php5-uploadprogress are built for SLES 11 and hosted by
      # the University of Stuttgart. Both have been shown to work with SLES 12.
      php_modules="apache2-mod_php5 php5-curl php5-fileinfo php5-gd php5-gettext \
        php5-mbstring php5-mysql php5-openssl php5-phar php5-posix php5-sockets \
        php5-uploadprogress php5-zip php5-zlib php5-readline php5-pcntl"
    fi
    install_command="zypper ${zypper_options} install ${zypper_install_options}"
    ;;
  debian)
    apache_pkg=apache2
    php_pkg=php5
    php_modules="libapache2-mod-php5 php5-gd php5-curl php5-mysql"
    
    install_command="apt-get -y install"
    ;;
esac

display "Installing Apache web server... please stand by"
display "-------------------------------------------------"
display "Command: $install_command $apache_pkg"
$install_command $apache_pkg >> $logfile 2>&1
display " "

display "Installing PHP... please stand by"
display "-------------------------------------------------"
display "Command: $install_command $php_pkg"
$install_command $php_pkg >> $logfile 2>&1
display " "

display "Installing PHP modules... please stand by"
display "-------------------------------------------------"
for php_module in $php_modules ; do
  display "Command: $install_command $php_module"
  $install_command $php_module >> $logfile 2>&1
done

if [[ $separate_mbstring_install -eq 1 ]]; then
  rpmfind_base=http://fr2.rpmfind.net/linux/centos/6/updates/x86_64/Packages/
  mbstring_rpm_file=$( curl $rpmfind_base 2>/dev/null | grep php-mbstring | head -n1 | sed 's/^.*<a href="//' | sed 's/">.*$//' )
  rpm -Uv ${rpmfind_base}/${mbstring_rpm_file} >> $logfile 2>&1
fi

display " "

