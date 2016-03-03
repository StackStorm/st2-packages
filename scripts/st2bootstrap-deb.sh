#!/bin/bash

set -eu

REPO_TYPE='staging' # XXX: Set this to 'production' when production becomes the shipping repo.
RELEASE='stable'
VERSION=''  # Should be major.minor.patch or major.minordev. E.g. 1.3.2 or 1.4dev.

# Private variables
BETA=1 # XXX: Remove this and other usages when production becomes the shipping repo
ST2_PKG_VERSION=''
ST2MISTRAL_PKG_VERSION=''
ST2WEB_PKG_VERSION=''

fail() {
  echo "############### ERROR ###############"
  echo "# Failed on step - $STEP #"
  echo "#####################################"
  exit 2
}

setup_args() {
  for i in "$@"
    do
      case $i in
          -V=*|--version=*)
          VERSION="${i#*=}"
          shift
          ;;
          -s=*|--stable)
        RELEASE=stable
          shift
          ;;
          -u=*|--unstable)
        RELEASE=unstable
          shift
          ;;
          --staging)
        REPO_TYPE='staging'
        shift
        ;;
          *)
                  # unknown option
          ;;
      esac
    done

  if [[ "$RELEASE" == "unstable" ]]; then
    echo "This script does not support installing from unstable sources!"
    # XXX: Fix this when st2mistral unstable sources become available!
    exit 1
  fi

  if [[ "$VERSION" != '' ]]; then
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
      echo "$VERSION does not match supported formats x.y.z or x.ydev"
      exit 1
    fi

    if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
     echo "You're requesting a dev version! Switching to unstable!"
     RELEASE='unstable'
    fi
  fi

  echo "########################################################"
  echo "          Installing st2 $RELEASE $VERSION              "
  echo "########################################################"

  if [[ -z "$BETA"  && "$REPO_TYPE"="staging" ]]; then
    printf "\n\n"
    echo "################################################################"
    echo "### Installing from staging repos!!! USE AT YOUR OWN RISK!!! ###"
    echo "################################################################"
  fi
}

install_st2_dependencies() {
  sudo apt-get update
  sudo apt-get install -y curl mongodb-server rabbitmq-server
}

get_full_pkg_versions() {
  if [ "$VERSION" != '' ];
  then
    local ST2_VER=$(apt-cache show st2 | grep Version | awk '{print $2}' | grep $VERSION | sort --version-sort | tail -n 1)
    if [ -z "$ST2_VER" ]; then
      echo "Could not find requested version of st2!!!"
      sudo apt-cache policy st2
      exit 3
    fi

    local ST2MISTRAL_VER=$(apt-cache show st2mistral | grep Version | awk '{print $2}' | grep $VERSION | sort --version-sort | tail -n 1)
    if [ -z "$ST2MISTRAL_VER" ]; then
      echo "Could not find requested version of st2mistral!!!"
      sudo apt-cache policy st2mistral
      exit 3
    fi

    local ST2WEB_VER=$(apt-cache show st2web | grep Version | awk '{print $2}' | grep $VERSION | sort --version-sort | tail -n 1)
    if [ -z "$ST2WEB_VER" ]; then
      echo "Could not find requested version of st2web."
      sudo apt-cache policy st2web
      exit 3
    fi
    ST2_PKG_VERSION="=${ST2_VER}"
    ST2MISTRAL_PKG_VERSION="=${ST2MISTRAL_VER}"
    ST2WEB_PKG_VERSION="=${ST2WEB_VER}"
    echo "##########################################################"
    echo "#### Following versions of packages will be installed ####"
    echo "st2${ST2_PKG_VERSION}"
    echo "st2mistral${ST2MISTRAL_PKG_VERSION}"
    echo "st2web${ST2WEB_PKG_VERSION}"
    echo "##########################################################"
  fi
}

install_st2() {
  # Following script adds a repo file, registers gpg key and runs apt-get update
  curl -s https://packagecloud.io/install/repositories/StackStorm/${REPO_TYPE}-${RELEASE}/script.deb.sh | sudo bash
  STEP="Get package versions" && get_full_pkg_versions && STEP="Install st2"
  sudo apt-get install -y st2${ST2_PKG_VERSION}
  sudo st2ctl reload
  sudo st2ctl start
}

configure_st2_user () {
  # Create an SSH system user (default `stanley` user may be already created)
  if (! id stanley 2>/dev/null); then
    sudo useradd stanley
  fi

  sudo mkdir -p /home/stanley/.ssh

  # Generate ssh keys on StackStorm box and copy over public key into remote box.
  sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""
  #sudo cp ${KEY_LOCATION}/stanley_rsa.pub /home/stanley/.ssh/stanley_rsa.pub

  # Authorize key-base acces
  sudo sh -c 'cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys'
  sudo chmod 0600 /home/stanley/.ssh/authorized_keys
  sudo chmod 0700 /home/stanley/.ssh
  sudo chown -R stanley:stanley /home/stanley

  # Enable passwordless sudo
  sudo sh -c 'echo "stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2'
  sudo chmod 0440 /etc/sudoers.d/st2

  ##### NOTE STILL NEED ADJUST CONFIGURATION FOR ST2 USER SECTION #####
}

configure_st2_authentication() {
  # Install htpasswd and tool for editing ini files
  sudo apt-get install -y apache2-utils crudini

  # Create a user record in a password file.
  sudo echo "Ch@ngeMe" | sudo htpasswd -i /etc/st2/htpasswd test

  # Configure [auth] section in st2.conf
  sudo crudini --set /etc/st2/st2.conf auth enable 'True'
  sudo crudini --set /etc/st2/st2.conf auth backend 'flat_file'
  sudo crudini --set /etc/st2/st2.conf auth backend_kwargs '{"file_path": "/etc/st2/htpasswd"}'

  sudo st2ctl restart-component st2api
}

install_st2mistral_depdendencies() {
  sudo apt-get install -y postgresql

  cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD
}

install_st2mistral() {
  # install mistral
  sudo apt-get install -y st2mistral${ST2MISTRAL_PKG_VERSION}

  # Setup Mistral DB tables, etc.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
  # Register mistral actions
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate
  
  # Start Mistral
  sudo service mistral start
}

install_st2web() {
  # Install st2web and nginx
  sudo apt-get install -y st2web${ST2WEB_PKG_VERSION} nginx

  # Generate self-signed certificate or place your existing certificate under /etc/ssl/st2
  sudo mkdir -p /etc/ssl/st2
  sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
  -days XXX -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information \
  Technology/CN=$(hostname)"

  # Remove default site, if present
  sudo rm -f /etc/nginx/sites-enabled/default
  # Copy and enable StackStorm's supplied config file
  sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/sites-available/
  sudo ln -s /etc/nginx/sites-available/st2.conf /etc/nginx/sites-enabled/st2.conf

  sudo service nginx restart
}

verify_st2() {
  st2 --version
  st2 -h

  st2 auth test -p Ch@ngeMe
  # A shortcut to authenticate and export the token
  export ST2_AUTH_TOKEN=$(st2 auth test -p Ch@ngeMe -t)

  # List the actions from a 'core' pack
  st2 action list --pack=core

  # Run a local shell command
  st2 run core.local -- date -R

  # See the execution results
  st2 execution list

  # Fire a remote comand via SSH (Requires passwordless SSH)
  st2 run core.remote hosts='127.0.0.1' -- uname -a

  # Install a pack
  st2 run packs.install packs=st2
}

ok_message() {
  echo ""
  echo ""
  echo "███████╗████████╗██████╗      ██████╗ ██╗  ██╗";
  echo "██╔════╝╚══██╔══╝╚════██╗    ██╔═══██╗██║ ██╔╝";
  echo "███████╗   ██║    █████╔╝    ██║   ██║█████╔╝ ";
  echo "╚════██║   ██║   ██╔═══╝     ██║   ██║██╔═██╗ ";
  echo "███████║   ██║   ███████╗    ╚██████╔╝██║  ██╗";
  echo "╚══════╝   ╚═╝   ╚══════╝     ╚═════╝ ╚═╝  ╚═╝";
  echo ""
  echo "  st2 is installed and ready to use."
  echo ""
  echo "Head to https://YOUR_HOST_IP/ to access the WebUI"
  echo ""
  echo "Don't forget to dive into our documentation! Here are some resources"
  echo "for you:"
  echo ""
  echo "* Documentation  - https://docs.stackstorm.com"
  echo "* Knowledge Base - https://stackstorm.reamaze.com"
  echo ""
  echo "Thanks for installing StackStorm! Come visit us in our Slack Channel"
  echo "and tell us how it's going. We'd love to hear from you!"
  echo "http://stackstorm.com/community-signup"
}

## Let's do this!

trap 'fail' EXIT
STEP="Setup args" && setup_args $@
STEP="Install st2 dependencies" && install_st2_dependencies
STEP="Install st2" && install_st2
STEP="Configure st2 user" && configure_st2_user
STEP="Configure st2 auth" && configure_st2_authentication
STEP="Verify st2" && verify_st2

STEP="Install mistral dependencies" && install_st2mistral_depdendencies
STEP="Install mistral" && install_st2mistral

STEP="Install st2web" && install_st2web
trap - EXIT

ok_message
