#!/bin/bash
#
# Script installs packages on to the host system
#
set -e
set -o pipefail
. $(dirname ${BASH_SOURCE[0]})/helpers.sh

install_debian() { sudo gdebi -nq "$1"; }
install_rhel() { sudo yum -y install "$1"; }

package_ext() { [ $(platform) = 'debian' ] && echo -n 'deb' || echo -n 'rpm'; }
package_path() {
  path=$(ls -1t ${ARTIFACTS_PATH}/$1*.$(package_ext) | head -n1)
  [ -z $path ] && _errexit=1 error "Couldn't find any package"
  echo $path
}

install_package() {
  package_path $1
  path="$(package_path $1)"
  pkgname=$(basename $path)
  pkgname=${pkgname%%.$(package_ext)}

  msg_proc "Staring installation of package: $pkgname"
  install_$(platform) "$path"
}

# --- Go!
debug "$0 has been invoked!"

export WHEELDIR=/tmp/wheelhouse
ARTIFACTS_PATH="${ARTIFACTS_PATH:-/root/build}"

# Check inputs
[ $# -eq 0 ] && _errexit=1 error "$0 expect non-empty argument list of packages"

for name in "$@"; do
  install_package $name
done
