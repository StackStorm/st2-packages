#!/bin/bash

export WHEELDIR=/tmp/wheelhouse
export TERM=xterm
export ST2_COMPONENTS=(st2actions st2api)

build_debian () {
  BUILD_LIST=${@:-$ST2_COMPONENTS}
  cd /code

  for makedir in "${BUILD_LIST[@]}"; do
    pushd $makedir && \
      dpkg-buildpackage -b -uc -us && \
      popd
  done
}

# --- Merge new debian makefiles with upstream
cp -r /sources/* /code

# --- Build st2common wheel
cd /code/st2common && \
  make wheelhouse && \
  python setup.py bdist_wheel -d $WHEELDIR 


# --- Run build
[ -f /etc/debian_version ] && build_debian "$@"
