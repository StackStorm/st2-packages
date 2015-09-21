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
  sudo cp -v $1*.deb $ARTIFACTS_PATH;
  sudo cp -v $1{*.changes,*.dsc} $ARTIFACTS_PATH || :;
}
copy_rhel() { sudo cp -v $RPMS/*/$1*.rpm $ARTIFACTS_PATH; }

build_package() {
  msg_proc "Starting package $1 build"

  # Pre-run make rules if needed. For example we need it for debian builds
  # to invoke changelog and populate_version
  for rule in $MAKE_PRERUN; do
    make "$rule"
  done

  build_$(platform) $1
  msg_proc "Finished package $1 build sucessfully"
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
  if [[ "$pkg" == st2* ]]; then
    # st2* components are sub directories of one git project
    # artifacts are found in top-level, ie git directory
    pushd $pkg && build_package $pkg && popd
    copy_artifact $pkg
  else
    # in other case artifacts is found level-up from the current
    # package git directory.
    build_package $pkg
    pushd ../ && copy_artifact $pkg && popd
  fi
done

popd

# Some debug info
debug "Contents of artifacts directory:" "`ls -la $ARTIFACTS_PATH`"
