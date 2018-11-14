#!/bin/bash
set -e

platform() {
  [ -f /etc/debian_version ] && { echo 'deb'; return 0; }
  echo 'rpm'
}

version_delemiter() {
  [ "$(platform)" = "deb" ] && echo '_' || echo '-'
}

remove_rpm() {
  sudo yum -y remove $@;
}

remove_deb() {
  sudo apt-get remove --purge -y $@
}

[ $# -eq 0 ] && { echo "usage: $0 (name | path) ..." && exit 1; }

remove_$(platform) "$@"
