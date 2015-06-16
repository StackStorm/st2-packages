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

if [ -z $1 ]; then
  # no cmd supplied
  [ -f /etc/debian_version ] && build_debian
else
  bash -c "$@"
fi
