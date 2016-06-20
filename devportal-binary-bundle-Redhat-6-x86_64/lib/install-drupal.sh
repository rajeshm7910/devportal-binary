#!/bin/bash

# Expected incoming vars:
#   $webroot
#   $temp_dir
#   $script_path
# It is presumed that composer has already been installed.

# Path and filename of the Dev Portal custom tarball
devportal_profile_tarfile_path=${script_path}/resources/devportal_profile.tgz

# Download Drupal core
display "Installing Drupal core..."

$drush_exe dl --yes --drupal-project-rename --destination=${temp_dir} drupal >> $logfile 2>&1
err=$?
if [ $err -ne 0 ] ; then
  display_error "drush error code: $err while running the following command: $drush_exe dl --yes --drupal-project-rename --destination=${temp_dir} drupal "
  display "Make sure your system is properly networked and run the installer again."
  exit
fi

# Web root directory was already configured earlier, so we can
# assume it exists and is empty.

# Move regular and hidden files
mv ${temp_dir}/drupal/* ${webroot}  >> $logfile 2>&1
mv ${temp_dir}/drupal/.[!.]* ${webroot}  >> $logfile 2>&1
rm -rf ${temp_dir}/drupal >> $logfile 2>&1

mkdir -p ${webroot}/sites/default/files >> $logfile 2>&1
mkdir -p ${webroot}/sites/default/private >> $logfile 2>&1
mkdir -p ${webroot}/sites/default/tmp >> $logfile 2>&1

cp ${webroot}/sites/default/default.settings.php ${webroot}/sites/default/settings.php >> $logfile 2>&1

display "Installing devportal profile..."
mkdir -p ${webroot}/profiles/apigee >> $logfile 2>&1
( cd ${webroot}/profiles/apigee && tar xzf  $devportal_profile_tarfile_path ) >> $logfile 2>&1

# Move the buildInfo file to root
cp ${script_path}/buildInfo ${webroot} >> $logfile 2>&1

# Modify apigee.make and apigee.info for OPDK-specific needs
(
  echo
  echo "; OPDK additions"
  echo "projects[backup_migrate][subdir] = \"contrib\""
  echo "projects[fast_404][subdir] = \"contrib\""
) >> ${webroot}/profiles/apigee/apigee.make
# Do not install sumo for OPDK; it is only relevant for cloud installs.
sed -i "/projects\[sumo\]/d" ${webroot}/profiles/apigee/apigee.make

(
  echo
  echo "dependencies[] = fast_404"
  echo "dependencies[] = backup_migrate"
) >> ${webroot}/profiles/apigee/apigee.info
if [[ $( grep -c ' = update' ${webroot}/profiles/apigee/apigee.info ) -eq 0 ]] ; then
  (
    echo
    echo "dependencies[] = update"
  ) >> ${webroot}/profiles/apigee/apigee.info
fi

# These three modules should not be installed by default in OPDK builds.
# - Sumo was removed from apigee.make above.
# - Environment Indicator is only relevant in multi-env setups.
# - Apigee GTM allows us to monitor admin page use; not relevant for OPDK.
# - Apigee checklist phones home with info; not relevant for OPDK.
for module in environment_indicator sumo apigee_gtm apigee_checklist; do
  sed -i "/^dependencies\[\] = ${module}$/d" ${webroot}/profiles/apigee/apigee.info
done

# Remove deprecated modules. These only exist in apigee.make to keep from
# breaking legacy installs.
for module in cck_phone commerce_worldpay contentapi eck gauth github_connect highcharts i18n node_export uuid_features; do
  sed -i "/^projects\[${module}\]/d" ${webroot}/profiles/apigee/apigee.make
done

# Only try to modify if file exists, which was not the case in earlier versions.
if [[ -f ${webroot}/profiles/apigee/modules/custom/devconnect/devconnect.admin.inc ]] ; then
  sed -i '/DEVCONNECT_SHOW_CONFIG_FIELDS/s/FALSE/TRUE/' ${webroot}/profiles/apigee/modules/custom/devconnect/devconnect.admin.inc
fi

[[ -f ${temp_dir}/drush-make.log ]] && rm -f ${temp_dir}/drush-make.log
display "Installing contributed themes, modules and libraries..."
display "(This might take a while. Please stand by...)"
( cd ${webroot}/profiles/apigee && $drush_exe make --concurrency=10 --no-core --no-gitinfofile --contrib-destination=. --yes --nocolor apigee.make ) 2>&1 | tee -a ${logfile} | tee -a ${temp_dir}/drush-make.log

# grep returns a return code of 1 if no matches were found, so we have to turn
# off error trapping here.
trap - ERR
error_count=$(grep -c "\\\[error\\\]" ${temp_dir}/drush-make.log)
register_exception_handlers
rm -f ${temp_dir}/drush-make.log
if [[ $error_count -gt 0 ]]; then
  display_error "One or more Drupal components failed to download."
  display_error "Sometimes this happens as a result of network load on drupal.org or other"
  display_error "sites from which code must be downloaded."
  display_error "Please re-run this script to try again."
  display_error "To see which components failed to download, try grepping the install"
  display_error "log for the string '[error]'."
  exit 1
fi

display "Downloading library dependencies..."
(
  cd ${webroot}/profiles/apigee/libraries/mgmt-api-php-sdk
  $composer_exe install --no-dev --no-progress
  if [[ ! -d vendor ]] ; then
    display_error "Failed to install Edge SDK dependencies. Is composer configured correctly?"
    display_error "Composer was installed at the following location:"
    display_error "> ${composer_exe}"
    exit 1
  fi
) >> $logfile 2>&1

# Highcharts may unzip into a subdirectory. Move relevant files to parent dir,
# and delete irrelevant ones.
display "Correcting Highcharts library paths..."
trap - ERR
(
  subdir="$( ls -d ${webroot}/profiles/apigee/libraries/highcharts/Highcharts-* )"
  if [[ ! -z "${subdir}" && -d "${subdir}" ]] ; then
    # Only move relevant directories, delete others.
    mv ${subdir}/{gfx,graphics,js} ${webroot}/profiles/apigee/libraries/highcharts/
    rm -rf ${subdir}
  else
    rm -rf ${webroot}/profiles/apigee/libraries/highcharts/{examples,exporting-server,index.htm}
  fi
) >> $logfile 2>&1
register_exception_handlers

display "Cleaning up extraneous files in contrib libraries & modules..."
(
  rm -rf ${webroot}/profiles/apigee/libraries/ckeditor/samples
  rm -rf ${webroot}/profiles/apigee/libraries/google-api-php-client/{examples,test}
  rm -f ${webroot}/profiles/apigee/libraries/jquery.cycle/example.html
  rm -rf ${webroot}/profiles/apigee/libraries/mediaelement/{demo,test}
  rm -rf ${webroot}/profiles/apigee/libraries/mgmt-api-php-sdk/vendor/guzzle/{docs,phing}
  rm -rf ${webroot}/profiles/apigee/libraries/plupload/examples
  rm -rf ${webroot}/profiles/apigee/libraries/SolrPhpClient/{phpdocs,tests}
  rm -rf ${webroot}/profiles/apigee/libraries/syntaxhighlighter/{index.html,tests}

  rm -rf ${webroot}/profiles/apigee/modules/contrib/ckeditor/includes/uicolor/samples
  rm -rf ${webroot}/profiles/apigee/modules/contrib/commerce_worldpay_business_gateway/worldpay\ page\ example
  rm -rf ${webroot}/profiles/apigee/modules/contrib/ctools/{ctools_plugin_example,help,page_manager/help}
  rm -rf ${webroot}/profiles/apigee/modules/contrib/devel/krumo/docs
  rm -f ${webroot}/profiles/apigee/modules/contrib/mailsystem/README.html
  rm -rf ${webroot}/profiles/apigee/modules/contrib/views{,_accordion}/help
) >> $logfile 2>&1

display "Removing text files from web root..."
rm -f ${webroot}/*.txt >> $logfile 2>&1

display "done."

