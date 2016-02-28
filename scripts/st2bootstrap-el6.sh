#!/bin/bash

set -eu

check_libffi_devel() {
  install_libffi_devel=$(sudo yum install -y libffi-devel || true)
  is_libffi_devel_available=$(echo $install_libffi_devel | grep "No package libffi-devel" || true)

  if [[ ! -z "$is_libffi_devel_available" ]]; then
    echo "Your box doesn't seem to have libffi-devel available to install. This installer"
    echo "requires libffi-devel to be available. To proceed, hand install libffi-devel"
    echo "version corresponding to libffi on the box. You can get the libffi version via"
    echo "   rpm -qa | grep libffi  "
    echo "Installer will now abort. Contact support for questions or see docs"
    echo "   https://docs.stackstorm.com/install/rhel6.html!"
    echo "Alternatively, you can use CentOS 6 for evaluation."
    exit 2
  fi
}

# Note that default SELINUX policies for RHEL7 differ with CentOS7. CentOS7 is more permissive by default
# Note that depending on distro assembly/settings you may need more rules to change
# Apply these changes OR disable selinux in /etc/selinux/config (manually)
adjust_selinux_policies() {
  is_enforcing=$(getenforce)
  if [ "$is_enforcing" = "Enforcing" ]; then
    # SELINUX management tools, not available for some minimal installations
    sudo yum install -y policycoreutils-python

    # Allow rabbitmq to use '25672' port, otherwise it will fail to start
    # Note grep -q like we use in EL7 script breaks on RHEL6 with broken pipe because
    # of weird interaction issue between semanage and grep. This behavior is not same
    # in some CentOS 6 boxes where semanage port --list | grep -q ${PORT} works fine. So
    # use this workaround unless you validate -q really works on RHEL 6.
    ret=$(sudo semanage port --list | grep 25672 || true)
    if [ -z "$ret" ]; then
      sudo semanage port -a -t amqp_port_t -p tcp 25672
    fi

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
    sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
  fi
  sudo yum -y install curl mongodb-server rabbitmq-server
  sudo service mongod start
  sudo service rabbitmq-server start
  sudo chkconfig mongod on
  sudo chkconfig rabbitmq-server on
}

install_st2() {
  curl -s https://packagecloud.io/install/repositories/StackStorm/staging-stable/script.rpm.sh | sudo bash
  sudo yum -y install st2
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
  sudo htpasswd -bs /etc/st2/htpasswd test Ch@ngeMe

  # Configure [auth] section in st2.conf
  sudo crudini --set /etc/st2/st2.conf auth enable 'True'
  sudo crudini --set /etc/st2/st2.conf auth backend 'flat_file'
  sudo crudini --set /etc/st2/st2.conf auth backend_kwargs '{"file_path": "/etc/st2/htpasswd"}'

  sudo st2ctl restart-component st2api
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

install_st2mistral_depdendencies() {
  if grep -q "CentOS" /etc/redhat-release; then
      sudo yum -y localinstall http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-2.noarch.rpm
  fi

  if grep -q "Red Hat" /etc/redhat-release; then
      sudo yum -y localinstall http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-redhat94-9.4-2.noarch.rpm
  fi

  sudo yum -y install postgresql94-server postgresql94-contrib postgresql94-devel

  # Setup postgresql at a first time
  sudo service postgresql-9.4 initdb

  # Make localhost connections to use an MD5-encrypted password for authentication
  sudo sed -i "s/\(host.*all.*all.*127.0.0.1\/32.*\)ident/\1md5/" /var/lib/pgsql/9.4/data/pg_hba.conf
  sudo sed -i "s/\(host.*all.*all.*::1\/128.*\)ident/\1md5/" /var/lib/pgsql/9.4/data/pg_hba.conf

  # Start PostgreSQL service
  sudo service postgresql-9.4 start
  sudo chkconfig postgresql-9.4 on

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
  sudo service mistral start
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

  # Disable default_server configuration in existing /etc/nginx/conf.d/default.conf
  sudo sed -i 's/default_server//g' /etc/nginx/conf.d/default.conf

  sudo service nginx start
  sudo chkconfig nginx on
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
STEP='Check libffi-devel availability' && check_libffi_devel
STEP='Adjust SELinux policies' && adjust_selinux_policies

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
