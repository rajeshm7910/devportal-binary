#!/bin/bash

###############################################################################
# Bash Toolkit: Useful functions for all scripts to use, such as user prompting
# and output display.
###############################################################################

# ------------------------------------------------------------------------------
# Prompt and get input from user for a yes or no
# question, defaulting to yes if they just hit <Enter>.
#
# Parameters:
#   first: Question message to display to user, will be appended
#     with "[Y/n]:".
#   second: Variable to store the answer into. Valid
#     values are "y" or "n".
#
# Example:
#   prompt_question_yes_or_no_default_yes "Do you like APIs?" likes_apis
#
prompt_question_yes_or_no_default_yes() {
  local question_message=$1
  local resultvar=$2
  local question_answered=n

  # Grab the value of the variable that is referred to as an argument (yes, it's like that)
  eval response_var=\$$2

  # Then check to see if said variable has already been set
  if [ -z "$response_var" ]; then
    until [[ $question_answered = "y" ]]; do
      display_nonewline "${question_message?} [Y/n]: "
      read answer
      if [[ -z $answer || "y" = $answer || "Y" = $answer ]]; then
        question_answered=y
        answer=y
        echo $answer >> ${logfile}
      elif [[ "n" = "$answer" || "N" = "$answer" ]]; then
        question_answered=y
        answer=n
        echo $answer >> ${logfile}
      else
        echo 'Please answer "y", "n" or <ENTER> for "y"'
      fi
    done
    eval $resultvar="'$answer'"

    # Write this question/answer to the config file
    if [ "y" = "$generate_autoinstall_config_file" ]; then
      echo "#" $question_message >> $capturefile
      echo $resultvar=$answer >> $capturefile
    fi
  else
    # It has been set (meaning it came from a config file), so just use that value
    eval $resultvar=\$$2
  fi
}

# ------------------------------------------------------------------------------
# Prompt and get input from user for a yes or no
# question, defaulting to yes if they just hit <Enter>.
#
# Parameters:
#   first: Question message to display to user, will be appended
#     with "[Y/n]:".
#   second: Variable to store the answer into. Valid
#     values are "y" or "n".
#
# Example:
#   prompt_question_yes_or_no_default_yes "Do you like APIs?" likes_apis
#
prompt_question_yes_or_no_default_no() {
  local question_message=$1
  local resultvar=$2
  local question_answered=n

  # Grab the value of the variable that is referred to as an argument (yes, it's like that)
  eval response_var=\$$2

  # Then check to see if said variable has already been set
  if [ -z "$response_var" ]; then
    until [[ $question_answered = "y" ]]; do
      display_nonewline "${question_message?} [y/N]: "
      read answer
      if [[ -z $answer || "n" = $answer || "N" = $answer ]]; then
        question_answered=y
        answer=n
        echo $answer >> ${logfile}
      elif [[ "y" = "$answer" || "Y" = "$answer" ]]; then
        question_answered=y
        answer=y
        echo $answer >> ${logfile}
      else
        echo 'Please answer "y", "n" or <ENTER> for "n"'
      fi
    done
    eval $resultvar="'$answer'"

    # Write this question/answer to the config file.
    if [ "y" = "$generate_autoinstall_config_file" ]; then
      echo "#" $question_message >> $capturefile
      echo $resultvar=$answer >> $capturefile
    fi
  else
    # It has been set (meaning it came from a config file), so just use that value.
    eval $resultvar=\$$2
  fi
}

# ------------------------------------------------------------------------------
# Ask user a question, then capture result to a variable.
#
# Parameters:
#   first: Question message to display to user.
#   second: Variable to store the answer into
#   third: Default value for user to use if they just hit <ENTER>.
#
# Example:
#   prompt_question_text_input "What is your favorite color?" color blue
#
prompt_question_text_input() {
  local question_message=$1
  local resultvar=$2
  local default_value=$3

  #grab the value of the variable that is referred to as an argument (yes, it's like that)
  eval response_var=\$$2

  #then check to see if said variable has already been set
  if [ -z "$response_var" ]; then

    if [[ ! -z $default_value ]]; then
      display_nonewline "${question_message?} [${default_value}]: "
    else
      display_nonewline "${question_message?} : "
    fi
    read answer
    if [[ -z $answer && ! -z $default_value ]]; then
      eval $resultvar="'$default_value'"
      echo $default_value >> ${logfile}
    else
      eval $resultvar="'$answer'"
      echo $answer >> ${logfile}
    fi

    # Write this question/answer to the config file
    if [ "y" = "$generate_autoinstall_config_file" ]; then
      echo "#" $question_message >> $capturefile
      echo $resultvar=$answer >> $capturefile
    fi
  else
    # It has been set (meaning it came from a config file), so just use that value
    eval $resultvar=\$$2
  fi
}

# ------------------------------------------------------------------------------
# Ask user a for a password without displaying on screen, then capture result
# to a variable.
#
# Parameters:
#   first: Text to prompt user with
#   second: Variable to store the answer into
#
# Example:
#   prompt_question_password_input "What is your PIN number?" pin_number
#
prompt_question_password_input() {
  local question_message=$1
  local resultvar=$2

  #grab the value of the variable that is referred to as an argument (yes, it's like that)
  eval response_var=\$$2

  #then check to see if said variable has already been set
  if [ -z "$response_var" ]; then
    unset bash_toolkit_answer
    blank_allowed=0
    while [[ $blank_allowed -eq 0 && -z $bash_toolkit_answer ]]; do
      display_nonewline "${question_message?} : "
      read -s bash_toolkit_answer
      echo ''
      if [[ $3 -eq 1 ]] ; then
        blank_allowed=1
      fi
    done
    eval $resultvar="'$bash_toolkit_answer'"
    echo "********" >> ${logfile}

    #write this question/answer to the config file
    if [ "y" = "$generate_autoinstall_config_file" ]; then
      echo "#" $question_message >> $capturefile
      echo $resultvar=$bash_toolkit_answer >> $capturefile
    fi
  else
    #it has been set (meaning it came from a config file), so just use that value
    eval $resultvar=\$$2
  fi
}


# ------------------------------------------------------------------------------
# Ask user a for a password without displaying on screen and ask user
# for password again for confirmation, then capture result
# to a variable.
#
# Parameters:
#   first: Text to prompt user with
#   second: Variable to store the answer into
#
# Example:
#   prompt_question_password_and_confirm_imput "What is super secret password?" password
#
function prompt_question_password_and_confirm_input() {
  local question_message=$1
  local resultvar=$2

  # Grab the value of the variable that is referred to as an argument (yes, it's like that)
  eval response_var=\$$2

  # Then check to see if said variable has already been set
  if [ -z "$response_var" ]; then
    # It has not, so ask the user
    bash_toolkit_password_valid=0
    while [ $bash_toolkit_password_valid -eq 0 ] ; do
      prompt_question_password_input "$question_message" bash_toolkit_pass
      prompt_question_password_input "Confirm password" bash_tookit_db_pass_confirm

      if [ "$bash_toolkit_pass" != "$bash_tookit_db_pass_confirm" ] ; then
        display_error "Password and password confirmation do not match."
        unset bash_toolkit_pass
        unset bash_tookit_db_pass_confirm
        bash_toolkit_password_valid=0
      else
        bash_toolkit_password_valid=1
      fi
    done
    eval $resultvar="'$bash_toolkit_pass'"

    # Write this question/answer to the config file
    if [ "y" = "$generate_autoinstall_config_file" ]; then
      echo "#" $question_message >> $capturefile
      echo $resultvar=$bash_toolkit_pass >> $capturefile
    fi
  else
    # It has been set (meaning it came from a config file), so just use that value
    eval $resultvar=\$$2
  fi
}
# ------------------------------------------------------------------------------
# Initialize script by creating log file, trapping errors, etc.
#
# Parameters:
# first: variable name of a temp directory if needed (optional)
#
script_initialize() {
  temp_dir_var=$1

  # Turn of case sensitive matching for our string compares
  shopt -s nocasematch

  # Set colors for displaying errors.
  export RED=$(tput setaf 1)
  export NORMAL=$(tput sgr0)

  # Get the date of script running
  export script_rundate="$(date '+%Y-%m-%d-%H.%M.%S')"

  # Register_exception_handler in case errors are thrown by other programs
  # or if user CTRL-C from script.
  register_exception_handlers

  # Call init_logfile function
  init_logfile

  # Temp dir will be created if temp_dir_var given.
  create_tmp_dir $temp_dir_var

  # Make sure /usr/local/bin is in the path.
  if [[ $( echo $PATH | grep -c '/usr/local/bin' ) -eq 0 ]]; then
    export PATH="${PATH}:/usr/local/bin"
  fi
}

# ------------------------------------------------------------------------------
# Create tmp directory if first param is set
#
# Parameters:
# first: variable name of a temp directory
#
function create_tmp_dir() {
    temp_dir_var=$1

    # create tmp directory
    if [[ ! -z $temp_dir_var ]] ; then
      bash_toolkit_get_tmp_directory bash_toolkit_temp_dir
      # Remove it if already exists.
      if [[ -d $bash_toolkit_temp_dir || -f $bash_toolkit_temp_dir ]]; then
        rm -rf $bash_toolkit_temp_dir
      fi
      mkdir $bash_toolkit_temp_dir
      eval $temp_dir_var="'$bash_toolkit_temp_dir'"
    fi
}

# ------------------------------------------------------------------------------
# Remove tmp directory when exiting
function remove_tmp_dir() {
  bash_toolkit_get_tmp_directory bash_toolkit_temp_dir
  # Remove tmp directory
  if [[ -d $bash_toolkit_temp_dir || -f $bash_toolkit_temp_dir ]]; then
    rm -rf $bash_toolkit_temp_dir
  fi

  if test -n "$(find /tmp -maxdepth 1 -name 'devportal-binary-bundle-*' -print -quit)"; then
    rm -rf /tmp/devportal-binary-bundle*
  fi
  if [[ -d /tmp/drupal ]] ; then
    rm -rf /tmp/drupal
  fi
}


# ------------------------------------------------------------------------------
# Display a dashed horizontal line.
#
# Example:
#   display_hr
#
display_hr() {
    display "--------------------------------------------------------------------------------"
}

# ------------------------------------------------------------------------------
# Display a major heading
#
# Parameters:
#   first: Message to display
#
# Example:
#   display_h1 "Starting Install"
#
display_h1() {
    display
    display_hr
    display $1
    display_hr
}

# ------------------------------------------------------------------------------
# Display error message to user in red.
#
# Parameters:
#   first: message to display
#
# Example:
#   display_error "Virus detected!"
#
display_error() {
  display "${RED}${1}${NORMAL}"
}

# ------------------------------------------------------------------------------
# Display messages in logfile and screen.
#
# Parameters:
#   first: message to display
#
# Example:
#   display "Hello World!"
#
display() {
  echo $@ 2>&1 | tee -a ${logfile}
}

display_nonewline() {
   printf -- "${@}" 2>&1 | tee -a ${logfile}
}

display_multiline() {
   display_nonewline "${1?}\n"
}


# ------------------------------------------------------------------------------
# Invoke the exception_handler on CTRL-C
#
# This funciton is called by script_initialize
#
register_exception_handlers() {
  # Bash defines pseudo-signals ERR and EXIT that can be used to trap any error or exit of the shell.
  trap trap_signal_error ERR
  # Interrupt from keyboard, someone hit CTRL-C
  trap trap_signal_sigint SIGINT
  # Trap normal exits
  trap trap_signal_exit EXIT
}

################################################################################
# PRIVATE functions
################################################################################

# ------------------------------------------------------------------------------
# PRIVATE function, call script_initialize.
#
# Initialize logfile for script.
#
init_logfile() {
  export logfile="${script_path}/install.log"
  if [ ! -e "$logfile" ] ; then
      touch "$logfile"
  fi

  if [ ! -w "$logfile" ] ; then
      echo "Cannot write to file: $logfile.  Please check permissions of this directory and file."
      exit 1
  fi
}

# ------------------------------------------------------------------------------
# PRIVATE function, call script_initialize.
#
# Clean up function called if signal caught.
#
function trap_signal_exit() {
    # Call function to remove tmp directory
    remove_tmp_dir
    exit 0
}

# ------------------------------------------------------------------------------
# PRIVATE function, call script_initialize.
#
# Clean up function called if signal caught.
#
function trap_signal_sigint() {
    # Call function to remove tmp directory
    remove_tmp_dir
    exit 1
}

# ------------------------------------------------------------------------------
# PRIVATE function, call script_initialize.
#
# Clean up function called if signal caught.
#
function trap_signal_error(){
  remove_tmp_dir
cat <<ENDOFMESSAGE
-------------------------------------------------------------
	${RED} Exiting, ERROR!

  The actions of this installer are written to a log here:

  ${logfile}

  If you need support during this installation,
  please include the logfile in your communication.${NORMAL}

  Here are the last few lines of the logfile for your convenience:

-------------------------------------------------------------

ENDOFMESSAGE

  tail -n 5 $logfile

cat <<-ENDOFMESSAGE

-------------------------------------------------------------
ENDOFMESSAGE

  exit 1
}

# ------------------------------------------------------------------------------
# PRIVATE function
#
# Get the tmp directory
#
# Parameters:
#   First: variable to set with script directory
#
function bash_toolkit_get_tmp_directory() {
  resultvar=$1
  # Get directory this script is running in and put it in SCRIPT_PATH
  bash_toolkit_cwd=`dirname $0`
  bash_toolkit_tmp_dir=${bash_toolkit_cwd}/tmp
  # Change path to the full absolute path now
  bash_toolkit_abs_tmp_dir=`readlink -f $bash_toolkit_tmp_dir`
  eval $resultvar="'$bash_toolkit_abs_tmp_dir'"
}
