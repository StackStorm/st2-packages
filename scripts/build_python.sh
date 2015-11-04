#!/bin/bash
set -e

build="${ST2_PYTHON}"
pyver="${ST2_PYTHON_VERSION}"
pyrel="${ST2_PYTHON_RELEASE}"
artifact_dir="${ARTIFACT_DIR}"

if [ "$build" != 1 ]; then
  echo "Python build skipped. If you want st2_python, set ST2_PYTHON to 1."
  exit 0
fi

# create bro dirs for rpmbuild
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# grab python source
curl -sSL http://www.python.org/ftp/python/$pyver/Python-$pyver.tar.xz -o \
  ~/rpmbuild/SOURCES/Python-$pyver.tar.xz

# invoke build
rpmbuild -bb st2python.spec

# copy artifact
cp ~/rpmbuild/RPMS/$(arch)/st2python*-$pyver-${ST2_PYTHON_RELEASE}*.rpm ${artifact_dir}
