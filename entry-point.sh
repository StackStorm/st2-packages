#!/bin/bash

export TERM=xterm
export WHEELDIR=/tmp/wheelhouse

#DEBUG=1

ST2_COMPONENTS=(st2common st2actions st2api st2auth st2client st2reactor)
[ -f /etc/debian_version ] && DEBIAN=1

move_packages () {
  [ $DEBIAN -eq 1 ] && mv /code/*.deb /code/*.changes /code/*.dsc /out
}

build_package () {
  [ $DEBIAN -eq 1 ] && dpkg-buildpackage -b -uc -us
}

build () {
  cd /code
  BUILD_LIST=(${@:-${ST2_COMPONENTS[@]}})
  for makedir in ${BUILD_LIST[@]}; do
    [ ! -d $makedir ] && { echo "Error: component \`${makedir}' not found"; exit 1; }
    echo
    echo "--------------- Creating package for ${makedir} ---------------"
    pushd $makedir && \
      build_package && popd
  done
}


# --- Merge new debian makefiles with upstream
cp -r /sources/* /code

echo
echo "--------------- Creating st2common wheel (in ${WHEELDIR}) ---------------"
cd /code/st2common && \
  make wheelhouse && \
  python setup.py bdist_wheel -d $WHEELDIR 

build "$@"
move_packages

# Don't exit container, for debug purposes
[ $DEBUG -eq 1 ] && sleep infinity
