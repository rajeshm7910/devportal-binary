#!/bin/bash

###############################################################################
# Check command line options
# Available Options:
#   -c filename
#      Config file
#   -h
#      Lists usage and flags
#

# Parse options
config_file='';
generate_autoinstall_config_file='n';
OPTIND=1 # Reset is necessary if getopts was used previously
while getopts "c:hb:" opt; do
  [[ "${opt}" == 'help' ]] && opt=h
  case $opt in
    c)
      # A config file has been specified, so use it
      config_file=$OPTARG
      echo "Config file was specified: $config_file"
      source $config_file
      ;;
    b)
      capturefile=$OPTARG
      generate_autoinstall_config_file='y'
      echo "Will build config file dynamically during this install: $capturefile"
      echo "Note: some inputs will not be captured and the file will need to be amended before use"
      ;;
    h)
      # Helpy help help
      echo
      echo
      echo "Usage: `basename $0` options (-c filename) (-b filename)"
      echo
      echo "Example: ./filename -c default.properties.auto"
      echo
      echo "Where options include:"
      echo "      -c filename  (use a specified config file)"
      echo "      -b filename  (build config file dynamically)"
      echo
      echo
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2;
      exit 1;
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2;
      exit 1;
      ;;
  esac
done

