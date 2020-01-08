#!/bin/bash
set -e

platform() {
  [ -f /etc/debian_version ] && { echo 'deb'; return 0; }
  echo 'rpm'
}

version_delemiter() {
  [ "$(platform)" = "deb" ] && echo '_' || echo '-'
}

install_rpm() {
  sudo yum -y install $(lookup_fullnames $@);
}

install_deb() {
  sudo apt-get -o Acquire::ForceIPv4=true update -y

  for fpath in $(lookup_fullnames $@); do
    echo "Installing package: $fpath"
    gdebi -o Acquire::ForceIPv4=true -o APT::Acquire::ForceIPv4=true -n "$fpath"
  done
}

lookup_fullnames() {
  list=""
  for name_or_path in "$@"; do
    path=""
    # If file exists and is readable
    if [[ -r "$name_or_path" ]]; then
      path="$name_or_path"
    # Try and find the st2* package file
    else
      regex="${name_or_path}$(version_delemiter)"'[0-9].*'
      path=$(ls -1 ${name_or_path}$(version_delemiter)*".$(platform)" | grep "$regex" | head -n1)
    fi
    [[ -z "$path" ]] && { echo "Couldn't find package: \`'$name_or_path'"; exit 1; }
    [[ -z "$list" ]] && list="$path" || list="$list $path"
  done
  echo $list
}

[[ $# -eq 0 ]] && { echo "usage: $0 (name | path) ..." && exit 1; }

install_$(platform) "$@"
