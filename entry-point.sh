#!/bin/bash

export TERM=xterm
export ST2_COMPONENTS=(st2api)


function create_st2common_wheel {
  cd /code/st2common
  make setup_py_prerequisites
  python setup.py bdist_wheel -d /tmp/wheelhouse
}

function build_debian {
  cd /code/st2api && \
    dpkg-buildpackage -b -uc -us && mv /code/*.deb /code/*.changes /code/*.dsc /out
}

# for component in "${ST2_COMPONENTS[@]}"; do
#   cd /code/$component && make wheelhouse
#   && dpkg-buildpackage -b -uc -us && \
#   mv /code/*.deb /code/*.changes /code/*.dsc /out  && \
#   dh_clean
# done


# Update sources with new Makefiles and debian/* files
cp -r /sources/* /code

# Empty command then build initiated
if [ -z $1 ]; then
  [ -f /etc/debian_version ] && build_debian
  sleep infinity # sleep for debug
else
  cp -r /sources/* /code
  bash -c "$@"
fi
