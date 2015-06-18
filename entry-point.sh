#!/bin/bash

export TERM=xterm
export ST2_COMPONENTS=(st2common)


function build_debian {
  for component in "${ST2_COMPONENTS[@]}"; do
    cd /code/$component && dpkg-buildpackage -b -uc -us && \
    mv /code/*.deb /code/*.changes /code/*.dsc /out  && \
    dh_clean
  done
}

# Update sources with new Makefiles and debian/* files
cp -r /sources/* /code

# Empty command then build initiated
if [ -z $1 ]; then
  [ -f /etc/debian_version ] && build_debian
  sleep infinity # sleep for debug
else
  bash -c "$@"
fi
