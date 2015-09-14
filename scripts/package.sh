#!/bin/bash
#
# Script prepares st2 repository and performs build of OS packages.
#
set -e
set -o pipefail
. $(dirname ${BASH_SOURCE[0]})/helpers.sh

build_debian() { dpkg-buildpackage -b -uc -us; }
build_rhel() { rpmbuild -bb rpm/$1.spec; }

copy_debian() {
  [ "$NOCHANGEDIR" = "1" ] && _up='../'
  sudo cp -v $_up$1{*.deb,*.changes,*.dsc} $ARTIFACTS_PATH || true;
}
copy_rhel() { sudo cp -v $RPMS/*/$1*.rpm $ARTIFACTS_PATH; }

build_package() {
  if [ ! -d "$1" ] && [ "$NOCHANGEDIR" != 1 ]; then
    _errexit=1 error "Package directory $1 not found (at $(pwd))"
  fi

  msg_proc "Starting package $1 build"

  [ "$NOCHANGEDIR" = "1" ] || pushd $1

  # Pre-run make rules if needed. For example we need it for debian builds
  # to invoke changelog and populate_version
  for rule in $MAKE_PRERUN; do
    make "$rule"
  done

  build_$(platform) $1
  msg_proc "Finished package $1 build sucessfully"
  [ "$NOCHANGEDIR" = "1" ] || popd
}

copy_artifact() {
  copy_$(platform) $1
}

# ---- Go!
export WHEELDIR=/tmp/wheelhouse
ARTIFACTS_PATH="${ARTIFACTS_PATH:-/root/build}"
RPMS="/root/rpmbuild/RPMS"

# Check inputs
[ $# -eq 0 ] && _errexit=1 error "$0 expect non-empty argument list of packages"
[ -d "$GITDIR" ] || _errexit=1 error "$0 requires GITDIR to be set and exist"

[ -d $ARTIFACTS_PATH ] || mkdir -p $ARTIFACTS_PATH

# Enter repo directory
pushd $GITDIR
for pkg in $@; do
  build_package $pkg
  copy_artifact $pkg
done
popd

# Some debug info
debug "Contents of artifacts directory:" "`ls -la $ARTIFACTS_PATH`"
