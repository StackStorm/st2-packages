#!/bin/bash
set -e
set -o pipefail

package_name="$1"
artifact_dir="${ARTIFACT_DIR}"
cores_num=$(/usr/bin/nproc)

export WHEELDIR

if [[ -z "$package_name" ]]; then
    echo "Usage: $0 package_name"
    exit 1;
fi

# Determine build target from available build software.
# Caveat: The case of RPM systems with debian build software installed or vice-versa is not handled.
if command -v dpkg-buildpackage; then
    export PKGTYPE=deb
elif command -v rpmbuild; then
    export PKGTYPE=rpm
else
    echo "Unable to build package because one of dpkg-buildpackage or rpmbuild wasn't found."
    echo "This means the build environment isn't setup correctly or the build system isn't supported."
    exit 1
fi

# NOTE: If you want to troubleshoot rpmbuild, add -vv flag to enable debug mode
build_rpm() {
    rpmbuild -bb --define '_topdir %(readlink -f build)' rpm/"$package_name".spec;
}

build_deb() {
    dpkg-buildpackage -b -uc -us -j"$cores_num"
}

copy_rpm() {
    sudo cp -v build/RPMS/*/$1*.rpm "$artifact_dir";
    # Also print some package info for easier troubleshooting
    rpm -q --requires -p build/RPMS/*/"$1"*.rpm
    rpm -q --provides -p build/RPMS/*/"$1"*.rpm
}

copy_deb() {
  sudo cp -v ../"$package_name"*.deb "$artifact_dir" || { echo "Failed to copy .deb file into artifact directory \`$artifact_dir'" ; exit 1; }
  sudo cp -v ../"$package_name"{*.changes,*.dsc} "$artifact_dir" || :;
}

"build_${PKGTYPE}"
"copy_${PKGTYPE}"
