#!/bin/bash
set -e
set -o pipefail

package_name="$1"

platform() {
  [ -f /etc/debian_version ] && { echo 'deb'; return 0; }
  echo 'rpm'
}

install_rpm() { sudo yum -y install "$(lookup_fullname $package_name)"; }
install_deb() { sudo gdebi -nq "$(lookup_fullname $package_name)"; }

lookup_fullname() {
  if [ -a "$1" ]; then
    path="$1"
  else
    path="$(ls -1t $1*.$(platform) | grep "$1-[0-9].*"| head -n1)"
  fi
  [ -z "$path" ] && { echo "Couldn't find package: \`'$package_name'"; exit 1; }
  echo "$path"
}

[ -z "$package_name" ] && { echo "usage: $0 package_name | package_path" && exit 1; }

install_$(platform)
