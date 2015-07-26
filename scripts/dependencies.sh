#!/bin/bash
set -e

#
# NOT USED, and supposed so far
#

# DEB / RPM
if [ -f /etc/debian_version ]; then
  export DEBIAN_FRONTEND=noninteractive

  PKGINST="sudo -E apt-get -qy install"
  DEPS="rabbitmq-server mongodb-server"
  SVCTL=sysv
  # SERVICES=

  [ "$MISTRAL_DISABLED" != 1 ] && DEPS="${DEPS} mysql-server"

  if (which start &>/dev/null) && (which start &>/dev/null); then
    SVCTL=upstart
  fi
else
  echo "Redhat is not supported yet"
  exit 1
fi

svctl() {
  action="$1"
  service="$2"

  sysv_fallback=1
  case $SVCTL in
    upstart|sysv)
      # Check that upstart job conf file exists then invoke command.
      if [ "$SVCTL" = upstart ] && [ -f /etc/init/${service}.conf ]; then
        $action $service
        sysv_fallback=0
      fi
      # Continue with sysv fallback
      if [ $sysv_fallback = 1 ]; then
        /etc/init.d/$service $action
      fi
    ;;
    *)
      echo "error: service control via ${SVCTL} is not supported"
      exit 1
    ;;
  esac
}

echo "===> Installing all st2 standalone dependencies"
# $PKGINST $DEPS

echo "===> Starting dependency services"
