#!/bin/bash

set -eu

USERNAME='test'
PASSWORD='Ch@ngeMe'

HUBOT_ADAPTER='slack'
HUBOT_SLACK_TOKEN=${HUBOT_SLACK_TOKEN:-''}
VERSION=''
RELEASE='stable'
REPO_TYPE='staging'
BETA=''
ST2_PKG_VERSION=''

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

# Note that default SELINUX policies for RHEL7 differ with CentOS7. CentOS7 is more permissive by default
# Note that depending on distro assembly/settings you may need more rules to change
# Apply these changes OR disable selinux in /etc/selinux/config (manually)
adjust_selinux_policies() {
  if getenforce | grep -q 'Enforcing'; then
    # SELINUX management tools, not available for some minimal installations
    sudo yum install -y policycoreutils-python

    # Allow rabbitmq to use '25672' port, otherwise it will fail to start
    sudo semanage port --list | grep -q 25672 || sudo semanage port -a -t amqp_port_t -p tcp 25672

    # Allow network access for nginx
    sudo setsebool -P httpd_can_network_connect 1
  fi
}

fail() {
  echo "############### ERROR ###############"
  echo "# Failed on $STEP #"
  echo "#####################################"
  exit 2
}

install_st2_dependencies() {
  is_epel_installed=$(rpm -qa | grep epel-release || true)
  if [[ -z "$is_epel_installed" ]]; then
    sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  fi
  sudo yum -y install curl mongodb-server rabbitmq-server
  sudo systemctl start mongod rabbitmq-server
  sudo systemctl enable mongod rabbitmq-server
}

install_st2() {
  curl -s https://packagecloud.io/install/repositories/StackStorm/${REPO_TYPE}-${RELEASE}/script.rpm.sh | sudo bash
  sudo yum -y install st2${ST2_PKG_VERSION}
  sudo st2ctl reload
  sudo st2ctl start
}

configure_st2_user() {
  # Create an SSH system user (default `stanley` user may be already created)
  if (! id stanley 2>/dev/null); then
    sudo useradd stanley
  fi

  sudo mkdir -p /home/stanley/.ssh
  sudo chmod 0700 /home/stanley/.ssh

  # On StackStorm host, generate ssh keys
  sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""

  # Authorize key-base acces
  sudo sh -c 'cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys'
  sudo chmod 0600 /home/stanley/.ssh/authorized_keys
  sudo chown -R stanley:stanley /home/stanley

  # Enable passwordless sudo
  sudo sh -c 'echo "stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2'
  sudo chmod 0440 /etc/sudoers.d/st2

  # Make sure `Defaults requiretty` is disabled in `/etc/sudoers`
  sudo sed -i "s/^Defaults\s\+requiretty/# Defaults requiretty/g" /etc/sudoers
}

configure_st2_authentication() {
  # Install htpasswd and tool for editing ini files
  sudo yum -y install httpd-tools crudini

  # Create a user record in a password file.
  echo $PASSWORD | sudo htpasswd -i /etc/st2/htpasswd $USERNAME

  # Configure [auth] section in st2.conf
  sudo crudini --set /etc/st2/st2.conf auth enable 'True'
  sudo crudini --set /etc/st2/st2.conf auth backend 'flat_file'
  sudo crudini --set /etc/st2/st2.conf auth backend_kwargs '{"file_path": "/etc/st2/htpasswd"}'

  sudo st2ctl restart-component st2api
}

verify_st2() {
  st2 --version
  st2 -h

  st2 auth $USERNAME -p $PASSWORD
  # A shortcut to authenticate and export the token
  export ST2_AUTH_TOKEN=$(st2 auth $USERNAME -p $PASSWORD -t)

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

install_st2mistral_depdendencies() {
  sudo yum -y install postgresql-server postgresql-contrib postgresql-devel

  # Setup postgresql at a first time
  sudo postgresql-setup initdb

  # Make localhost connections to use an MD5-encrypted password for authentication
  sudo sed -i "s/\(host.*all.*all.*127.0.0.1\/32.*\)ident/\1md5/" /var/lib/pgsql/data/pg_hba.conf
  sudo sed -i "s/\(host.*all.*all.*::1\/128.*\)ident/\1md5/" /var/lib/pgsql/data/pg_hba.conf

  # Start PostgreSQL service
  sudo systemctl start postgresql
  sudo systemctl enable postgresql

  cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD
}

install_st2mistral() {
  # install mistral
  sudo yum -y install st2mistral

  # Setup Mistral DB tables, etc.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
  # Register mistral actions
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate

  # start mistral
  sudo systemctl start mistral
}

install_st2web() {
  # Install st2web and nginx
  sudo yum install -y st2web nginx

  # Generate self-signed certificate or place your existing certificate under /etc/ssl/st2
  sudo mkdir -p /etc/ssl/st2

  sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
  -days 365 -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information Technology/CN=$(hostname)"

  # Copy and enable StackStorm's supplied config file
  sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/conf.d/

  # Disable default_server configuration in existing /etc/nginx/nginx.conf
  sudo sed -i 's/default_server//g' /etc/nginx/nginx.conf

  sudo systemctl restart nginx
  sudo systemctl enable nginx
}

install_st2chatops() {
  # Install Node
  curl -sL https://rpm.nodesource.com/setup_4.x | sudo -E bash -
  sudo yum install -y nodejs

  # Install st2chatops
  sudo yum install -y st2chatops
}

configure_st2chatops() {
  # Set credentials
  sudo sed -i -r "s/^(export ST2_AUTH_USERNAME.).*/\1$USERNAME/" /opt/stackstorm/chatops/st2chatops.env
  sudo sed -i -r "s/^(export ST2_AUTH_PASSWORD.).*/\1$PASSWORD/" /opt/stackstorm/chatops/st2chatops.env

  # Setup adapter
  if [ "$HUBOT_ADAPTER"="slack" ] && [ ! -z "$HUBOT_SLACK_TOKEN" ]
  then
    sudo sed -i -r "s/^# (export HUBOT_ADAPTER=slack)/\1/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^# (export HUBOT_SLACK_TOKEN.).*/\1/" st2chatops.env
    sudo sed -i -r "s/^(export HUBOT_ADAPTER.).*/\1$HUBOT_ADAPTER/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export HUBOT_SLACK_TOKEN.).*/\1$HUBOT_SLACK_TOKEN/" /opt/stackstorm/chatops/st2chatops.env

    sudo systemctl st2chatops restart
    sudo systemctl enable st2chatops
  else
    echo "####################### WARNING ########################"
    echo "######## Chatops requires manual configuration #########"
    echo "Edit /opt/stackstorm/chatops/st2chatops.env to specify  "
    echo "the adapter and settings hubot should use to connect to "
    echo "the chat you're using. Don't forget to start the service"
    echo "afterwards:"
    echo ""
    echo "  $ sudo service st2chatops restart"
    echo ""
    echo "For more information, please refer to documentation at  "
    echo "https://docs.stackstorm.com/install/deb.html#setup-chatops"
    echo "########################################################"
  fi
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

trap 'fail' EXIT
STEP='Adjust SELinux policies' && adjust_selinux_policies

STEP="Install st2 dependencies" && install_st2_dependencies
STEP="Install st2" && install_st2
STEP="Configure st2 user" && configure_st2_user
STEP="Configure st2 auth" && configure_st2_authentication
STEP="Verify st2" && verify_st2

STEP="Install mistral dependencies" && install_st2mistral_depdendencies
STEP="Install mistral" && install_st2mistral

STEP="Install st2web" && install_st2web
STEP="Install st2chatops" && install_st2chatops
STEP="Configure st2chatops" && configure_st2chatops
trap - EXIT

ok_message
