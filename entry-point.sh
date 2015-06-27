#!/bin/bash

export WHEELDIR=/tmp/wheelhouse
export TERM=xterm
export ST2_COMPONENTS=(st2actions st2api st2auth st2client st2reactor)

build_debian () {
  BUILD_LIST=(${@:-${ST2_COMPONENTS[@]}})
  cd /code

  echo "++++++++++++++++++++++++++++++++++++"
  echo "${BUILD_LIST[@]}"

  for makedir in ${BUILD_LIST[@]}; do
    echo
    echo "--------------- Creating debian package for ${makedir} ---------------"
    pushd $makedir && \
      dpkg-buildpackage -b -uc -us && \
      popd
  done
  mv /code/*.deb /code/*.changes /code/*.dsc /out
}

# --- Merge new debian makefiles with upstream
cp -r /sources/* /code

echo
echo "--------------- Creating st2common wheel (in ${WHEELDIR}) ---------------"
cd /code/st2common && \
  make wheelhouse && \
  python setup.py bdist_wheel -d $WHEELDIR 


# --- Run build
[ -f /etc/debian_version ] && build_debian "$@"
