set -eu

HUBOT_ADAPTER='slack'
HUBOT_SLACK_TOKEN=${HUBOT_SLACK_TOKEN:-''}
VERSION=''
RELEASE='stable'
REPO_TYPE=''
REPO_PREFIX=''
ST2_PKG_VERSION=''
DEV_BUILD=''
USERNAME=''
PASSWORD=''
ST2_PKG='st2'
ST2MISTRAL_PKG='st2mistral'
ST2WEB_PKG='st2web'
ST2CHATOPS_PKG='st2chatops'

setup_args() {
  for i in "$@"
    do
      case $i in
          -v|--version=*)
          VERSION="${i#*=}"
          shift
          ;;
          -s|--stable)
          RELEASE=stable
          shift
          ;;
          -u|--unstable)
          RELEASE=unstable
          shift
          ;;
          --staging)
          REPO_TYPE='staging'
          shift
          ;;
          --dev=*)
          DEV_BUILD="${i#*=}"
          shift
          ;;
          --user=*)
          USERNAME="${i#*=}"
          shift
          ;;
          --password=*)
          PASSWORD="${i#*=}"
          shift
          ;;
          *)
          # unknown option
          ;;
      esac
    done

  if [[ "$REPO_TYPE" != '' ]]; then
      REPO_PREFIX="${REPO_TYPE}-"
  fi

  if [[ "$VERSION" != '' ]]; then
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
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

  if [ "$REPO_TYPE" == "staging" ]; then
    printf "\n\n"
    echo "################################################################"
    echo "### Installing from staging repos!!! USE AT YOUR OWN RISK!!! ###"
    echo "################################################################"
  fi

  if [ "$DEV_BUILD" != '' ]; then
    printf "\n\n"
    echo "###############################################################################"
    echo "### Installing from dev build artifacts!!! REALLY, ANYTHING COULD HAPPEN!!! ###"
    echo "###############################################################################"
  fi

  if [[ "$USERNAME" = '' || "$PASSWORD" = '' ]]; then
    echo "Let's set StackStorm admin credentials."
    echo "You can also use \"--user\" and \"--password\" for unattended installation."
    echo "Press \"ENTER\" to continue or \"CTRL+C\" to exit/abort"
    read -e -p "Admin username: " -i "st2admin" USERNAME
    read -e -s -p "Password: " PASSWORD

    if [ "${PASSWORD}" = '' ]; then
        echo "Password cannot be empty."
        exit 1
    fi
  fi
}


# include:includes/common.sh
# include:includes/rhel.sh


check_libffi_devel() {
  local message= no_libffi_devel=
message=$(cat <<EHD
No repository containing libffi-devel package has been located!
Setup "server-optional" repository following instructions
https://access.redhat.com/solutions/265523. After adding the repository using
your preferred method (subscription or yum-utils) please re-run this script!

If you still have questions, please contact support. Alternatively, you can use
CentOS 6 for evaluation.
EHD
)
  sudo yum list libffi-devel 1>/dev/null 2>&1 || no_libffi_devel=$?
  if [ ! -z "$no_libffi_devel" ]; then
    echo "$message"
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

    # Allow network access for nginx
    sudo setsebool -P httpd_can_network_connect 1
  fi
}


install_st2_dependencies() {
  is_epel_installed=$(rpm -qa | grep epel-release || true)
  if [[ -z "$is_epel_installed" ]]; then
    sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
  fi
  sudo yum -y install curl rabbitmq-server

  # Configure RabbitMQ to listen on localhost only
  sudo sh -c 'echo "RABBITMQ_NODE_IP_ADDRESS=127.0.0.1" >> /etc/rabbitmq/rabbitmq-env.conf'

  sudo service rabbitmq-server start
  sudo chkconfig rabbitmq-server on

  # Various other dependencies needed by st2 and installer script
  sudo yum -y install crudini
}

install_mongodb() {
  # Add key and repo for the latest stable MongoDB (3.4)
  sudo rpm --import https://www.mongodb.org/static/pgp/server-3.4.asc
  sudo sh -c "cat <<EOT > /etc/yum.repos.d/mongodb-org-3.4.repo
[mongodb-org-3.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/6Server/mongodb-org/3.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOT"

  sudo yum -y install mongodb-org

  # Configure MongoDB to listen on localhost only
  sudo sed -i -e "s#bindIp:.*#bindIp: 127.0.0.1#g" /etc/mongod.conf

  sudo service mongod start
  sudo chkconfig mongod on

  sleep 5

  # Create admin user and user used by StackStorm (MongoDB needs to be running)
  mongo <<EOF
use admin;
db.createUser({
    user: "admin",
    pwd: "${ST2_MONGODB_PASSWORD}",
    roles: [
        { role: "userAdminAnyDatabase", db: "admin" }
    ]
});
quit();
EOF

  mongo <<EOF
use st2;
db.createUser({
    user: "stackstorm",
    pwd: "${ST2_MONGODB_PASSWORD}",
    roles: [
        { role: "readWrite", db: "st2" }
    ]
});
quit();
EOF

  # Require authentication to be able to acccess the database
  sudo sh -c 'echo -e "security:\n  authorization: enabled" >> /etc/mongod.conf'

  # MongoDB needs to be restarted after enabling auth
  sudo service mongod restart
}

install_st2() {
  curl -s https://packagecloud.io/install/repositories/StackStorm/${REPO_PREFIX}${RELEASE}/script.rpm.sh | sudo bash

  # 'mistral' repo builds single 'st2mistral' package and so we have to install 'st2' from repo
  if [ "$DEV_BUILD" = '' ] || [[ "$DEV_BUILD" =~ ^mistral/.* ]]; then
    STEP="Get package versions" && get_full_pkg_versions && STEP="Install st2"
    sudo yum -y install ${ST2_PKG}
  else
    sudo yum -y install jq

    PACKAGE_URL=$(get_package_url "${DEV_BUILD}" "el6" "st2-.*.rpm")
    sudo yum -y install ${PACKAGE_URL}
  fi

  # Configure [database] section in st2.conf (username password for MongoDB access)
  sudo crudini --set /etc/st2/st2.conf database username "stackstorm"
  sudo crudini --set /etc/st2/st2.conf database password "${ST2_MONGODB_PASSWORD}"

  sudo st2ctl start
  sudo st2ctl reload --register-all
}


configure_st2_authentication() {
  # Install htpasswd tool
  sudo yum -y install httpd-tools

  # Create a user record in a password file.
  sudo htpasswd -bs /etc/st2/htpasswd $USERNAME $PASSWORD

  # Configure [auth] section in st2.conf
  sudo crudini --set /etc/st2/st2.conf auth enable 'True'
  sudo crudini --set /etc/st2/st2.conf auth backend 'flat_file'
  sudo crudini --set /etc/st2/st2.conf auth backend_kwargs '{"file_path": "/etc/st2/htpasswd"}'

  sudo st2ctl restart-component st2api
  sudo st2ctl restart-component st2stream
}


install_st2mistral_dependencies() {
  if grep -q "CentOS" /etc/redhat-release; then
      sudo yum -y localinstall http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-2.noarch.rpm
  fi

  if grep -q "Red Hat" /etc/redhat-release; then
      sudo yum -y localinstall http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-redhat94-9.4-2.noarch.rpm
  fi

  sudo yum -y install postgresql94-server postgresql94-contrib postgresql94-devel

  # Setup postgresql at a first time
  sudo service postgresql-9.4 initdb

  # Configure service only listens on localhost
  sudo sh -c "echo \"listen_addresses = '127.0.0.1'\" >> /var/lib/pgsql/9.4/data/postgresql.conf"

  # Make localhost connections to use an MD5-encrypted password for authentication
  sudo sed -i "s/\(host.*all.*all.*127.0.0.1\/32.*\)ident/\1md5/" /var/lib/pgsql/9.4/data/pg_hba.conf
  sudo sed -i "s/\(host.*all.*all.*::1\/128.*\)ident/\1md5/" /var/lib/pgsql/9.4/data/pg_hba.conf

  # Start PostgreSQL service
  sudo service postgresql-9.4 start
  sudo chkconfig postgresql-9.4 on

  cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD '${ST2_POSTGRESQL_PASSWORD}';
CREATE DATABASE mistral OWNER mistral;
EHD
}

install_st2mistral() {
  # 'st2' repo builds single 'st2' package and so we have to install 'st2mistral' from repo
  if [ "$DEV_BUILD" = '' ] || [[ "$DEV_BUILD" =~ ^st2/.* ]]; then
    sudo yum -y install ${ST2MISTRAL_PKG}
  else
    sudo yum -y install jq

    PACKAGE_URL=$(get_package_url "${DEV_BUILD}" "el6" "st2mistral-.*.rpm")
    sudo yum -y install ${PACKAGE_URL}
  fi

  # Configure database settings
  sudo crudini --set /etc/mistral/mistral.conf database connection "postgresql+psycopg2://mistral:${ST2_POSTGRESQL_PASSWORD}@127.0.0.1/mistral"

  # Setup Mistral DB tables, etc.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head

  # Register mistral actions.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate | grep -v openstack

  # start mistral
  sudo service mistral start
}

install_st2web() {
  # Add key and repo for the latest stable nginx
  sudo rpm --import https://nginx.org/keys/nginx_signing.key
  sudo sh -c "cat <<EOT > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=https://nginx.org/packages/rhel/6/x86_64/
gpgcheck=1
enabled=1
EOT"

  # Install nginx
  sudo yum --disablerepo='epel' install -y nginx
  # Install st2web
  sudo yum install -y ${ST2WEB_PKG}

  # Generate self-signed certificate or place your existing certificate under /etc/ssl/st2
  sudo mkdir -p /etc/ssl/st2

  sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
  -days 365 -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information Technology/CN=$(hostname)"

  # Remove default site, if present
  sudo rm -f /etc/nginx/conf.d/default.conf

  # Copy and enable StackStorm's supplied config file
  sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/conf.d/

  sudo service nginx start
  sudo chkconfig nginx on
}

install_st2chatops() {
  # Add NodeJS 6 repo
  curl -sL https://rpm.nodesource.com/setup_6.x | sudo -E bash -

  # Install st2chatops
  sudo yum install -y ${ST2CHATOPS_PKG}
}

configure_st2chatops() {
  # set API keys. This should work since CLI is configuered already.
  ST2_API_KEY=`st2 apikey create -k`
  sudo sed -i -r "s/^(export ST2_API_KEY.).*/\1$ST2_API_KEY/" /opt/stackstorm/chatops/st2chatops.env

  sudo sed -i -r "s/^(export ST2_AUTH_URL.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
  sudo sed -i -r "s/^(export ST2_AUTH_USERNAME.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
  sudo sed -i -r "s/^(export ST2_AUTH_PASSWORD.).*/# &/" /opt/stackstorm/chatops/st2chatops.env

  # Setup adapter
  if [ "$HUBOT_ADAPTER"="slack" ] && [ ! -z "$HUBOT_SLACK_TOKEN" ]
  then
    sudo sed -i -r "s/^# (export HUBOT_ADAPTER=slack)/\1/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^# (export HUBOT_SLACK_TOKEN.).*/\1/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export HUBOT_ADAPTER.).*/\1$HUBOT_ADAPTER/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export HUBOT_SLACK_TOKEN.).*/\1$HUBOT_SLACK_TOKEN/" /opt/stackstorm/chatops/st2chatops.env
    sudo service st2chatops restart
    sudo chkconfig st2chatops on
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
    echo "https://docs.stackstorm.com/install/rhel6.html#setup-chatops"
    echo "########################################################"
  fi
}


trap 'fail' EXIT
STEP='Parse arguments' && setup_args $@
STEP="Configure Proxy" && configure_proxy
STEP="Check TCP ports and MongoDB storage requirements" && check_st2_host_dependencies
STEP='Check libffi-devel availability' && check_libffi_devel
STEP='Adjust SELinux policies' && adjust_selinux_policies
STEP='Install repoquery tool' && install_yum_utils
STEP="Generate random password" && generate_random_passwords

STEP="Install st2 dependencies" && install_st2_dependencies
STEP="Install st2 dependencies (MongoDB)" && install_mongodb
STEP="Install st2" && install_st2
STEP="Configure st2 user" && configure_st2_user
STEP="Configure st2 auth" && configure_st2_authentication
STEP="Configure st2 CLI config" && configure_st2_cli_config
STEP="Generate symmetric crypto key for datastore" && generate_symmetric_crypto_key_for_datastore
STEP="Verify st2" && verify_st2

STEP="Install mistral dependencies" && install_st2mistral_dependencies
STEP="Install mistral" && install_st2mistral

STEP="Install st2web" && install_st2web
STEP="Install st2chatops" && install_st2chatops
STEP="Configure st2chatops" && configure_st2chatops
trap - EXIT

ok_message
