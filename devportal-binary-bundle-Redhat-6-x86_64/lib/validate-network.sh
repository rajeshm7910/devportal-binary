#!/bin/bash

validation_url="https://www.github.com/"

display "Validating network is available"
# The following cURL call should generate a 301 redirect to https://github.com/.
cmd="curl --silent --location --fail --head --max-time 5 ${validation_url}"
trap - ERR
curl_exit_code=$?
response_headers="$( ${cmd} )"
response_ok=$( echo "${response_headers}" | grep -c "HTTP/1.[01] 200 OK" )

# Check response of curl.
if [[ $response_ok -gt 0 ]]; then
  # Network connections success, exit out of this script.
  display "Successfully connected to ${validation_url}."
else
  # Display info on network failure.
  display_error "Cannot connect to ${validation_url}."

  # If the date of the machine is not set (or other reasons), curl will
  # fail with error code 60 (Peer certificate cannot be authenticated with
  # known CA certificates.)
  if [[ $curl_exit_code -eq 60 ]]; then
    display_error "cURL Error: Peer certificate cannot be authenticated with known CA certificates."
    display_error "cURL performs SSL certificate verification by default but has failed checking"
    display_error "${validation_url}.  Make sure your system's date is set properly."
  elif [[ $curl_exit_code -ne 0 ]]; then
    display_error "cURL encountered error number ${curl_exit_code} while attempting to connect"
    display_error "to ${validation_url}. You can look up the meaning of this number here:"
    display_error "   http://curl.haxx.se/libcurl/c/libcurl-errors.html"
    display_error "The exact cURL command which was attempted is as follows:"
    display_error "   ${cmd}"
  elif [[ -z $response_headers ]]; then
    display_error "The hostname could not be resolved, or the remote host timed out."
    display_error "Please make sure this computer is properly connected to the internet."
  else
    display_error "The remote host responded with an error condition."
    display_error "The response headers are as follows:"
    display_multiline "${response_headers}"
    display_error "If you are connecting through a proxy, please make sure your proxy"
    display_error "is properly configured to redirect HTTPS requests correctly."
  fi

  exit 1
fi
