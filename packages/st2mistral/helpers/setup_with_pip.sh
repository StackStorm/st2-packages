#!/bin/sh
# This scripts installs pre-built st2mistral wheel into the system.
# 1) It works 100% for st2 bundled mistral package.
# 2) It may not work for other system mistral packages, such as
#      python-mistral for ubuntu, or openstack-mistral
#      from https://github.com/openstack-packages/mistral.
#    But anyway we give it a shot.

ST2PIP=/usr/share/python/mistral/bin/pip


# Locate binary (even on shells which don't support which)
# ps. it doesn't return 1 status as original which does.
_which() { # it should not have which name!
  binpaths=$(echo $PATH | sed 's/:/ /g')
  which=$(find $binpaths -type f -name which -print -quit)
  if [ -z $which ]; then
    find $(echo $PATH | sed 's/:/ /g') -type f -name $@ -print -quit
  else
    echo $which
  fi
}


locate_pip() {
  if [ -x $ST2PIP ]; then
    echo $ST2PIP
  else
    # Fallback to pip found in system paths.  
    _which pip
  fi 
}

fail() {
  echo "System pip couldn't be located. :("
cat <<EHD
  It's suggested to use mistral package of st2 team. 
  However, this package might work for you if you are using system packages:
  python-mistral for ubuntu/debian or openstack-mistral for rhel or your
  mistral installation is available system-wide (no virtualenv used).
EHD
  exit 1 # exit if pip is not found
}

# invoke st2mistral install/uninstall
st2mistral() {
  local PIPOPTS="--find-links /usr/share/st2mistral"

  pip=$(locate_pip)
  if [ $1 = install ]; then
    [ -z $pip ] && fail
    # Don't look for dependencies, since our package has them installed
    if [ $pip = "$ST2PIP" ]; then
      PIPOPTS="${PIPOPTS} --no-index"
    fi
    $pip install $PIPOPTS st2mistral &>/dev/null
  elif [ $1 = uninstall ]; then
    # Don't fail if no pip and if no st2mistral
    [ -z $pip ] && return 0
    yes | $pip uninstall st2mistral &>/dev/null || :
  fi
}
