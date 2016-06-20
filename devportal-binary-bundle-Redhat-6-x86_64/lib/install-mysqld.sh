#!/bin/bash

# Expected vars:
#   $opdk_os_major
#   $logfile
#   $platform_variant

case $platform_variant in
  rhel)
    if [[ $has_network -eq 0 ]]; then
      yum_options="--disablerepo=* --enablerepo=devportal --nogpgcheck"
    else
      yum_options=
    fi
    if [[ $opdk_os_major -eq 6 ]] ; then
      db_server_display=MySQL
      db_service_name=mysqld
      db_package_name=mysql-server
    else
      db_server_display=MariaDB
      db_service_name=mariadb
      db_package_name="mariadb mariadb-server"
    fi
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
    db_server_display=MySQL
    db_service_name=mysql
    ;;
  debian)
    db_server_display=MySQL
    db_service_name=mysql
    ;;
esac

# Install MySQL (RHEL/CentOS 6, SuSE, Ubuntu) or MariaDB (RHEL/CentOS 7)
display_multiline "
The Dev Portal database can be installed in a local
${db_server_display} server or you can choose to not install a database server
and instead configure Dev Portal to connect to a remote MySQL/MariaDB server.

If you choose to install ${db_server_display} locally, the database
user will be created for you.

If you choose to not install ${db_server_display} server on this
machine, you will be asked for the database server hostname, database user,
and database password later in this script.

You can use CTRL-C to exit out of this script and rerun it again if
needed.
"

prompt_question_yes_or_no_default_yes "Would you like to install ${db_server_display} Server on this system?" install_mysql_server
if [[ $install_mysql_server = "y" ]] ; then
  display "Installing ${db_server_display} server... please be patient"
  case $platform_variant in
    rhel)
      # On Cent/RHEL 7, mysql-server installs mariadb/galera
      yum install -y $yum_options ${db_package_name} >> $logfile 2>&1
      ;;
    suse)
      zypper ${zypper_options} install ${zypper_install_options} mysql  >> $logfile 2>&1
      ;;
    debian)
      already_has_mysqlserver=$( dpkg --get-selections | grep -v deinstall | sed -E "s/[[:space:]]+.*//g" | grep -c "^mysql-server$" )
      if [[ $already_has_mysqlserver -eq 0 ]] ; then
        prompt_question_password_and_confirm_input "Set password for MySQL root user" db_root_pass
        echo "mysql-server mysql-server/root_password password ${db_root_pass}" | debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password ${db_root_pass}" | debconf-set-selections
      fi
      apt-get -y install mysql-server >> $logfile 2>&1
      ;;
  esac
  display "Making sure ${db_server_display} runs at startup"
  case $platform_variant in
    rhel)
      if [[ $opdk_os_major -eq 6 ]] ; then
        chkconfig --levels 35 ${db_service_name} on  >> $logfile 2>&1
      else
        systemctl enable ${db_service_name}.service   >> $logfile 2>&1
      fi
      ;;
    suse)
      chkconfig ${db_service_name} 35  >> $logfile 2>&1
      # Remove any existing max_allowed_packet entries and add our valid one.
      sed -i -e '/^max_allowed_packet/d' -e '/\[mysqld\]/a max_allowed_packet = 16M' /etc/my.cnf
      ;;
    debian)
      update-rc.d ${db_service_name} defaults >> $logfile 2>&1
      ;;
  esac

  echo "max_allowed_packet=32M" >> /etc/my.cnf

  if [[ $platform_variant = "rhel" && $opdk_os_major -gt 6 ]] ; then
    # RHEL 7 and above uses systemd.
    systemctl restart ${db_service_name}.service >> $logfile 2>&1
  else
    if [[ $( service ${db_service_name} status | grep -c 'stopped' ) -eq 1 ]] ; then
      display "Starting ${db_server_display} server..."
      service ${db_service_name} start  >> $logfile 2>&1
    else
      display "Restarting ${db_server_display} server..."
      service ${db_service_name} restart  >> $logfile 2>&1
    fi
  fi

fi

# Connect to MySQL database and create schema.
if [[ $install_mysql_server = "y" ]] ; then
  # The root password on install of MySQL is always blank.
  db_root_pass=""
  prompt_question_text_input "Name of Dev Portal database to be created" db_name devportal
  prompt_question_text_input "Database user to be created" db_user devportal
  db_port=3306
  db_host=localhost

  # Make sure user puts in a password.
  prompt_question_password_and_confirm_input "Set password for database user ${db_user}" db_pass

  # Create database.
  mysql -u root --password=${db_root_pass} -e "CREATE DATABASE IF NOT EXISTS ${db_name}"; >> $logfile 2>&1

  # Check to see if user exists.
  is_user_created=$( mysql -u root --password=${db_root_pass} --skip-column-names -e "SELECT COUNT(*) FROM mysql.user WHERE user='${db_name}' AND host='localhost'" )

  if [ $is_user_created -eq 0 ]; then
    display "Creating ${db_server_display} user ${db_user}..."
    mysql -u root  -e "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';" >> $logfile 2>&1
    mysql -u root  -e "GRANT ALL ON ${db_name}.* TO '${db_user}'@'localhost';" >> $logfile 2>&1
    mysql -u root  -e 'FLUSH PRIVILEGES;' >> $logfile 2>&1
  else
    display "${db_server_display} user ${db_user} already exists, updating password."
    mysql -u root  -e "SET PASSWORD FOR '${db_user}'@'localhost' = PASSWORD('${db_pass}');" >> $logfile 2>&1
  fi
else
  # MySQL server is not installed locally, validate we can connect.
  display_multiline "

  ${db_server_display} server has not been installed, so you will need to supply
  the connection information when using the web browser later in the install
  process.

  Please make sure the database user has the following rights:
    SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY
    TABLES, LOCK TABLES."

fi

display "${db_server_display} Server configured."
