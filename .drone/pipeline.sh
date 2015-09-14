#!/bin/bash

sc_dir="$(dirname ${BASH_SOURCE[0]})"
. $(dirname $sc_dir)/scripts/helpers.sh

# Define build pipeline variables, by marking them with the prefix: _pv_.
# Also create local corresponding vars without prefix.
# _pv_ vars will be available on remote hosts without prefix.
#
pipe_env() {
  if [ $# -eq 0 ]; then
    ( set -o posix ; set ) | grep "^_pv_" | sed 's/^_pv_//'
  else
    for ev in "$@"; do
      if [[ "$ev" == *"="* ]]; then
        eval "$ev"
        eval "_pv_$ev"
      else
        value=$(eval echo "\$$ev")
        if [ ! -z "$value" ]; then
          eval "$ev=$value"
          eval "_pv_$ev=$value"
        fi
      fi
    done
  fi
}

# Create remote variables export list
#
remote_exports() {
  pipe_env | sed 's/^/export /'
}

# Setup ssh agent for busybee user
#
setup_busybee_sshenv() {
  if [ -z "$SSH_AUTH_SOCK" ] && [ -z "$SSH_AGENT_PID" ]; then
    eval $(ssh-agent)
  fi
  ssh-add /root/.ssh/busybee

  cat > /root/.ssh/config <<EHD
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EHD
}

# Recursivly copy files to a remote host
#
ssh_copy() {
  dest="${@: -1}"
  if [[ "$dest" == ?*":"* ]]; then
    scp -r $@ 1>/dev/null
  else
    _errexit=1 error "can't copy to a remote host, wrong scp destination \`$dest'"
  fi
}

# Print some details
#
print_details() {
  # cat docker linked hosts info
  debug "Docker linked hosts >>>" "$(cat /etc/hosts | grep '172.17')"
}

# Try to resolve hostname ip address from /etc/host
#
hosts_resolve_ip(){
  if [ ! -z $1 ]; then
    _ipaddr=$(getent hosts $1 | awk '{ print $1 }')
    [ -z "$_ipaddr" ] && echo $1 || echo $_ipaddr
  fi
}

# Run ssh command on a remote host
#
ssh_cmd() {
  host="$1" && shift
  ssh "$host"  "$(remote_exports)""
               bash -c \"$@\""
}

# Checkout project from git repository
#
checkout_repo() {
  if [ ! -z "$BUILDHOST" ]; then
    msg_proc "Checking out" "- $GITURL@$GITREV"
    ssh_cmd $BUILDHOST 'git clone --depth 1 -b $GITREV $GITURL $GITDIR'
  else
    warn "\n..... Skipping source checkout, BUILDHOST is not specified!"
  fi
}

# Build packages on a remote node (providing customized build environment)
#
build_packages() {
  if [ ! -z "$BUILDHOST" ]; then
    msg_proc "Starting build on $BUILDHOST" "package list: [$(echo \"$@\" | xargs)]"
    ssh_cmd $BUILDHOST bash scripts/package.sh "$@"
  else
    warn "Skipping the build stage, BUILDHOST is not specified!"
  fi
}

# Preapre test host for running tests
#
testhost_setup() {
  host_addr=$(hosts_resolve_ip $1)
  msg_proc "Preparing for tests on" "- $1"
  ssh_copy scripts $host_addr:

  source /etc/profile.d/rvm.sh
  bundle install
}


# Install stactorm packages on to remote test host
#
install_packages() {
  host="$1"; shift
  # We can't use volumes_from in Drone, that's why perform scp
  # inside drone environment.
  if [ "$COMPOSE" != "1" ]; then
    msg_proc "Transfer build artifacts to" "- $host"
    ssh_copy -3 "$(hosts_resolve_ip $BUILDHOST)":build $(hosts_resolve_ip $host):
  fi

  # invoke packages installation
  ssh_cmd $host /bin/bash scripts/install.sh $@

  # invoke config rewrite on the test host, only when needed
  if [[ "$@" == *"st2common"* || "$@" == *"st2bundle"* ]]; then
    ssh_cmd $host /bin/bash scripts/config.sh
  fi
}

# Start rspec on a remote test hosts
#
run_rspec() {
  msg_proc "Starting integration tests on $1"
  source /etc/profile.d/rvm.sh

  # exporting env for rspec
  export {ST2_PACKAGES,ST2_WAITFORSTART,MONGODBHOST,RABBITMQHOST,POSTGRESHOST}

  if ( is_full_build "$TESTLIST") || [ "$TESTLIST" = "st2bundle" ]; then
    TESTLIST="$TESTLIST" TESTHOST="$1" rspec spec
  else
    TESTLIST="$TESTLIST" TESTHOST="$1" rspec -P '**/package_*_spec.rb' spec
  fi
}

# Exit if can not run integration tests
#
is_full_build() {
  required=$(echo $ST2_PACKAGES | xargs -n1 | sed '/st2debug/d' | sort -u | xargs)
  given=$(echo "$@" | xargs -n1 | sort -u | xargs)
  for package in $required; do
    [[ "$given" == *"$package"* ]] || return 1
  done
  return 0
}

# Evaluate ordered list of components
#
components_list() {
  _components=""
  for cmp in ${ST2_BUILDLIST:-${ST2_PACKAGES}}; do
    if [[ "$ST2_PACKAGES" == *"$cmp"* ]]; then
      _components="$_components $cmp"
    fi
  done

  _components="$(echo "$_components" | xargs -n1 | sort -u | grep -v st2common | xargs)"
  [ -z "$_components" ] || _components="st2common $_components"

  if ( is_full_build "$_components" ); then
    _components="$_components st2bundle"
    pipe_env BUNDLE=1
  fi
  echo -n "$_components"
}
