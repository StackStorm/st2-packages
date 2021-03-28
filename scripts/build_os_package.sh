#!/bin/bash
set -e
set -o pipefail

package_name="$1"
artifact_dir="${ARTIFACT_DIR}"
cores_num=$(/usr/bin/nproc)

export WHEELDIR

platform() {
  [[ -f /etc/debian_version ]] && { echo 'deb'; return 0; }
  echo 'rpm'
}

# NOTE: If you want to troubleshoot rpmbuild, add -vv flag to enable debug mode
build_rpm() { rpmbuild -bb -vv --define '_topdir %(readlink -f build)' rpm/"$package_name".spec; }
build_deb() { dpkg-buildpackage -b -uc -us -j"$cores_num"; }

copy_rpm() {
    sudo cp -v build/RPMS/*/$1*.rpm "$artifact_dir";
    # Also print some package info for easier troubleshooting
    rpm -q --requires build/RPMS/*/$1*.rpm
    rpm -q --provides build/RPMS/*/$1*.rpm
}
copy_deb() {
  sudo cp -v ../"$package_name"*.deb "$artifact_dir" || { echo "Failed to copy .deb file into artifact directory \`$artifact_dir'" ; exit 1; }
  sudo cp -v ../"$package_name"{*.changes,*.dsc} "$artifact_dir" || :;
}

[[ -z "$package_name" ]] && { echo "usage: $0 package_name" && exit 1; }

build_$(platform)
copy_$(platform)
