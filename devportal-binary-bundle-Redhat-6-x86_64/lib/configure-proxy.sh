#!/bin/bash

display_multiline "
  This installer needs to be able to download software from the Internet via
  HTTP/HTTPS. If this server cannot directly access the Internet or is not
  already configured to connect through a proxy, you will need to configure
  your proxy settings now.

"

prompt_question_yes_or_no_default_no "Do you need to configure this server to connect to a proxy?" need_proxy

if [[ $need_proxy = 'y' ]] ; then
  prompt_question_text_input "Proxy hostname or IP address" proxy_host
  prompt_question_text_input "Proxy protocol" proxy_protocol "http"
  prompt_question_text_input "Username (if any) used to authenticate with proxy" proxy_user
  if [[ -z $proxy_user ]] ; then
    proxy_pass=
  else
    prompt_question_password_input "Password used to authenticate with proxy" proxy_pass
  fi
  prompt_question_text_input "Port on which proxy is listening" proxy_port "1080"

  if [[ -z $proxy_user || -z $proxy_pass ]] ; then
    proxy_user_pass=
  else
    proxy_user_pass="${proxy_user}:${proxy_pass}@"
  fi

  export http_proxy="${proxy_protocol}://${proxy_user_pass}${proxy_host}:${proxy_port}/"
  export https_proxy="${http_proxy}"
  export ftp_proxy="${http_proxy}"
fi
