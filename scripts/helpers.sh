#!/bin/bash

platform() {
  if [ -f /etc/debian_version ]; then
    echo 'debian'
  else
    echo 'rhel'
  fi
}

# magic_print :)
magic_print() {
  local header="$_mpHEADER"
  local ionum=${_mpIONUM:-1}

  first="$1"; shift;
  headline=$(echo "$first" | sed -n '1p')
  trailing=$(echo "$first" | sed '1d')
  spaces=$(printf "%${#header}s")

  >&$ionum echo -e "${header}${headline}"
  [ -z "$trailing" ] && text=("$@") || text=("$trailing" "$@")

  for lines in "${text[@]}"; do
    echo -e "$lines" | sed "s/^/$spaces/" 1>&$ionum
  done
}

debug_enabled() { [ "$DEBUG" = 1 ]; }

debug() {
  if debug_enabled; then
    _mpIONUM=2 _mpHEADER="DEBUG: " magic_print "$@"
  fi
}

warn() {
  if debug_enabled; then
    _mpHEADER="WARN: " magic_print "$@"
  fi
}

msg_info() {
  _mpHEADER="$_mpHEADER" magic_print "$@"
}

msg_proc() {
  echo
  _mpHEADER="===> " magic_print "$@"
}

error() {
  _mpIONUM=2 _mpHEADER="ERROR: " magic_print "$@"
  [ -z "$_errexit" ] && exit $_errexit
}
