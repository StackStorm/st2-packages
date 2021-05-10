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
ST2WEB_PKG='st2web'
ST2CHATOPS_PKG='st2chatops'

setup_args() {
  for i in "$@"
    do
      case $i in
          -v=*|--version=*)
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

install_net_tools() {
  # Install netstat
  sudo yum install -y net-tools
}

install_st2_dependencies() {
  is_epel_installed=$(rpm -qa | grep epel-release || true)
  if [[ -z "$is_epel_installed" ]]; then
    sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  fi
  
  # Various other dependencies needed by st2 and installer script
  sudo yum -y install crudini

  # Ensure python3-devel is available for download. By default is available on
  # CentOS, but for RHEL need to subscribe to the optional-rpms repo
  if ! sudo yum info python3-devel 1> /dev/null 2>&1; then
      # Python3-devel not available in current repositories - need to enable optional-server repo
      OPTIONAL_RPM_REPO=$(yum repolist disabled 2> /dev/null | awk -F'/' '/rhel-7-server-rhui-optional-rpms|rhui-REGION-rhel-server-optional|rhel-7-server-optional-rpms/{print $1}')

      if [[ "$OPTIONAL_RPM_REPO" != '' ]]; then
          # Attempt to install python3-devel temporarily with repo
          sudo yum install -y python3-devel --enablerepo ${OPTIONAL_RPM_REPO} 
      fi

      # Verify python3-devel now available
      sudo yum info python3-devel
  fi
}

install_rabbitmq() {
  sudo yum -y install curl rabbitmq-server

  # Configure RabbitMQ to listen on localhost only
  sudo sh -c 'echo "RABBITMQ_NODE_IP_ADDRESS=127.0.0.1" >> /etc/rabbitmq/rabbitmq-env.conf'

  sudo systemctl start rabbitmq-server
  sudo systemctl enable rabbitmq-server

  sudo rabbitmqctl add_user stackstorm "${ST2_RABBITMQ_PASSWORD}"
  sudo rabbitmqctl delete_user guest
  sudo rabbitmqctl set_user_tags stackstorm administrator
  sudo rabbitmqctl set_permissions -p / stackstorm ".*" ".*" ".*"
}

install_mongodb() {
  # Add key and repo for the latest stable MongoDB (4.0)
  sudo rpm --import https://www.mongodb.org/static/pgp/server-4.0.asc
  sudo sh -c "cat <<EOT > /etc/yum.repos.d/mongodb-org-4.repo
[mongodb-org-4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.0.asc
EOT"

  sudo yum -y install mongodb-org

  # Configure MongoDB to listen on localhost only
  sudo sed -i -e "s#bindIp:.*#bindIp: 127.0.0.1#g" /etc/mongod.conf

  sudo systemctl start mongod
  sudo systemctl enable mongod

  sleep 5

  # Create admin user and user used by StackStorm (MongoDB needs to be running)
  # NOTE: mongo shell will automatically exit when piping from stdin. There is
  # no need to put quit(); at the end. This way last command exit code will be
  # correctly preserved and install script will correctly fail and abort if this
  # command fails.
  mongo <<EOF
use admin;
db.createUser({
    user: "admin",
    pwd: "${ST2_MONGODB_PASSWORD}",
    roles: [
        { role: "userAdminAnyDatabase", db: "admin" }
    ]
});
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
EOF

  # Require authentication to be able to acccess the database
  sudo sh -c 'printf "security:\n  authorization: enabled\n" >> /etc/mongod.conf'

  # MongoDB needs to be restarted after enabling auth
  sudo systemctl restart mongod
}

install_redis() {
  # Install Redis Server. By default, redis only listen on localhost only.
  sudo yum install -y redis
  sudo systemctl start redis
  sudo systemctl enable redis
}

install_st2() {
  curl -sL https://packagecloud.io/install/repositories/StackStorm/${REPO_PREFIX}${RELEASE}/script.rpm.sh | sudo bash

  if [[ "$DEV_BUILD" = '' ]]; then
    STEP="Get package versions" && get_full_pkg_versions && STEP="Install st2"
    sudo yum -y install ${ST2_PKG}
  else
    sudo yum -y install jq

    PACKAGE_URL=$(get_package_url "${DEV_BUILD}" "el7" "st2-.*.rpm")
    sudo yum -y install ${PACKAGE_URL}
  fi

  # Configure [database] section in st2.conf (username password for MongoDB access)
  sudo crudini --set /etc/st2/st2.conf database username "stackstorm"
  sudo crudini --set /etc/st2/st2.conf database password "${ST2_MONGODB_PASSWORD}"

  # Configure [messaging] section in st2.conf (username password for RabbitMQ access)
  AMQP="amqp://stackstorm:$ST2_RABBITMQ_PASSWORD@127.0.0.1:5672"
  sudo crudini --set /etc/st2/st2.conf messaging url "${AMQP}"

  # Configure [coordination] section in st2.conf (url for Redis access)
  sudo crudini --set /etc/st2/st2.conf coordination url "redis://127.0.0.1:6379"

  sudo st2ctl start
  sudo st2ctl reload --register-all
}


configure_st2_authentication() {
  # Install htpasswd tool
  sudo yum -y install httpd-tools

  # Create a user record in a password file.
  echo ${PASSWORD} | sudo htpasswd -i /etc/st2/htpasswd ${USERNAME}

  # Configure [auth] section in st2.conf
  sudo crudini --set /etc/st2/st2.conf auth enable 'True'
  sudo crudini --set /etc/st2/st2.conf auth backend 'flat_file'
  sudo crudini --set /etc/st2/st2.conf auth backend_kwargs '{"file_path": "/etc/st2/htpasswd"}'

  sudo st2ctl restart-component st2auth
  sudo st2ctl restart-component st2api
  sudo st2ctl restart-component st2stream
}


install_st2web() {
  # Add key and repo for the latest stable nginx
  sudo rpm --import http://nginx.org/keys/nginx_signing.key
  sudo sh -c "cat <<EOT > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/7/x86_64/
gpgcheck=1
enabled=1
EOT"

  # Ensure that EPEL repo is not used for nginx
  sudo sed -i 's/^\(enabled=1\)$/exclude=nginx\n\1/g' /etc/yum.repos.d/epel.repo

  # Install nginx
  sudo yum install -y nginx

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

  sudo systemctl restart nginx
  sudo systemctl enable nginx
}

install_st2chatops() {
  # Temporary hack until proper upstream fix https://bugs.centos.org/view.php?id=13669
  if ! yum list http-parser 1>/dev/null 2>&1; then
    sudo yum install -y https://kojipkgs.fedoraproject.org//packages/http-parser/2.7.1/3.el7/x86_64/http-parser-2.7.1-3.el7.x86_64.rpm
  fi

  # Add NodeJS 10 repo
  curl -sL https://rpm.nodesource.com/setup_10.x | sudo -E bash -

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

    sudo systemctl restart st2chatops
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
    echo "https://docs.stackstorm.com/install/rhel7.html#setup-chatops"
    echo "########################################################"
  fi
}

trap 'fail' EXIT
STEP='Parse arguments' && setup_args $@
STEP="Configure Proxy" && configure_proxy
STEP='Install net-tools' && install_net_tools
STEP="Check TCP ports and MongoDB storage requirements" && check_st2_host_dependencies
STEP='Adjust SELinux policies' && adjust_selinux_policies
STEP='Install repoquery tool' && install_yum_utils
STEP="Generate random password" && generate_random_passwords

STEP="Install st2 dependencies" && install_st2_dependencies
STEP="Install st2 dependencies (RabbitMQ)" && install_rabbitmq
STEP="Install st2 dependencies (MongoDB)" && install_mongodb
STEP="Install st2 dependencies (Redis)" && install_redis
STEP="Install st2" && install_st2
STEP="Configure st2 user" && configure_st2_user
STEP="Configure st2 auth" && configure_st2_authentication
STEP="Configure st2 CLI config" && configure_st2_cli_config
STEP="Generate symmetric crypto key for datastore" && generate_symmetric_crypto_key_for_datastore
STEP="Verify st2" && verify_st2


STEP="Install st2web" && install_st2web
STEP="Install st2chatops" && install_st2chatops
STEP="Configure st2chatops" && configure_st2chatops
trap - EXIT

ok_message
