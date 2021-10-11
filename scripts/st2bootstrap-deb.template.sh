set -eu

HUBOT_ADAPTER='slack'
HUBOT_SLACK_TOKEN=${HUBOT_SLACK_TOKEN:-''}
VERSION=''
RELEASE='stable'
REPO_TYPE=''
REPO_PREFIX=''
ST2_PKG_VERSION=''
ST2WEB_PKG_VERSION=''
ST2CHATOPS_PKG_VERSION=''
DEV_BUILD=''
USERNAME=''
PASSWORD=''
U16_ADD_INSECURE_PY3_PPA=0
SUBTYPE=`lsb_release -cs`

if [[ "$SUBTYPE" != 'focal' && "$SUBTYPE" != 'bionic' ]]; then
  echo "Unsupported ubuntu codename ${SUBTYPE}. Please use Ubuntu 18.04 (bionic) or Ubuntu 20.04 (focal) as base system!"
  exit 2
fi

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
          # Provide flag to enable installing Python3 from 3rd party insecure PPA for Ubuntu Xenial
          # TODO: Remove once Ubuntu Xenial is dropped
          --u16-add-insecure-py3-ppa)
          U16_ADD_INSECURE_PY3_PPA=1
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
  echo "          Installing StackStorm $RELEASE $VERSION              "
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


install_st2_dependencies() {
  # Silence debconf prompt, raised during some dep installations. This will be passed to sudo via 'env_keep'.
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update

  sudo apt-get install -y curl

  # Various other dependencies needed by st2 and installer script
  sudo apt-get install -y crudini
}

install_rabbitmq() {
  # Install pre-req
  sudo apt-get install -y gnupg apt-transport-https

  # Team RabbitMQ's main signing key
  curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null
  # Launchpad PPA that provides modern Erlang releases
  curl -1sLf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf77f1eda57ebb1cc" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg > /dev/null
  # PackageCloud RabbitMQ repository
curl -1sLf "https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/io.packagecloud.rabbitmq.gpg > /dev/null

  # Add apt repositories maintained by Team RabbitMQ
  sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
 ## Provides modern Erlang/OTP releases
##
deb [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu ${SUBTYPE} main
deb-src [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu ${SUBTYPE} main

## Provides RabbitMQ
##
deb [signed-by=/usr/share/keyrings/io.packagecloud.rabbitmq.gpg] https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ ${SUBTYPE} main
deb-src [signed-by=/usr/share/keyrings/io.packagecloud.rabbitmq.gpg] https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ ${SUBTYPE} main
EOF

  # Update package indices
  sudo apt-get update -y

  # Install Erlang packages
  sudo apt-get install -y erlang-base \
                        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                        erlang-runtime-tools erlang-snmp erlang-ssl \
                        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

  # Install rabbitmq-server and its dependencies
  sudo apt-get install rabbitmq-server -y --fix-missing
  # configure RabbitMQ
  sudo rabbitmqctl add_user stackstorm "${ST2_RABBITMQ_PASSWORD}"
  sudo rabbitmqctl delete_user guest
  sudo rabbitmqctl set_user_tags stackstorm administrator
  sudo rabbitmqctl set_permissions -p / stackstorm ".*" ".*" ".*"

  # Configure RabbitMQ to listen on localhost only
  sudo sh -c 'echo "RABBITMQ_NODE_IP_ADDRESS=127.0.0.1" >> /etc/rabbitmq/rabbitmq-env.conf'

  sudo systemctl restart rabbitmq-server

}

install_mongodb() {
  # Add key and repo for the latest stable MongoDB 4.0
  if [[ "$SUBTYPE" = 'focal' ]]; then
    MONGO_VERSION="4.4"
  else
    MONGO_VERSION="4.0"
  fi

  wget -qO - https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc | sudo apt-key add -
  echo "deb http://repo.mongodb.org/apt/ubuntu ${SUBTYPE}/mongodb-org/${MONGO_VERSION} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list

  # Install MongoDB
  sudo apt-get update
  sudo apt-get install -y mongodb-org

  # Configure MongoDB to listen on localhost only
  sudo sed -i -e "s#bindIp:.*#bindIp: 127.0.0.1#g" /etc/mongod.conf

  # Enable and restart
  sudo systemctl enable mongod
  sudo systemctl start mongod

  # Wait for service to come up before attempt to create user
  sleep 10

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
  sudo apt-get install -y redis-server
}

get_full_pkg_versions() {
  if [[ "$VERSION" != '' ]];
  then
    local ST2_VER=$(apt-cache show st2 | grep Version | awk '{print $2}' | grep ^${VERSION//./\\.} | sort --version-sort | tail -n 1)
    if [[ -z "$ST2_VER" ]]; then
      echo "Could not find requested version of StackStorm!!!"
      sudo apt-cache policy st2
      exit 3
    fi

    local ST2WEB_VER=$(apt-cache show st2web | grep Version | awk '{print $2}' | grep ^${VERSION//./\\.} | sort --version-sort | tail -n 1)
    if [[ -z "$ST2WEB_VER" ]]; then
      echo "Could not find requested version of st2web."
      sudo apt-cache policy st2web
      exit 3
    fi

    local ST2CHATOPS_VER=$(apt-cache show st2chatops | grep Version | awk '{print $2}' | grep ^${VERSION//./\\.} | sort --version-sort | tail -n 1)
    if [[ -z "$ST2CHATOPS_VER" ]]; then
      echo "Could not find requested version of st2chatops."
      sudo apt-cache policy st2chatops
      exit 3
    fi

    ST2_PKG_VERSION="=${ST2_VER}"
    ST2WEB_PKG_VERSION="=${ST2WEB_VER}"
    ST2CHATOPS_PKG_VERSION="=${ST2CHATOPS_VER}"
    echo "##########################################################"
    echo "#### Following versions of packages will be installed ####"
    echo "st2${ST2_PKG_VERSION}"
    echo "st2web${ST2WEB_PKG_VERSION}"
    echo "st2chatops${ST2CHATOPS_PKG_VERSION}"
    echo "##########################################################"
  fi
}

install_st2() {
  # Following script adds a repo file, registers gpg key and runs apt-get update
  curl -sL https://packagecloud.io/install/repositories/StackStorm/${REPO_PREFIX}${RELEASE}/script.deb.sh | sudo bash

  if [[ "$DEV_BUILD" = '' ]]; then
    STEP="Get package versions" && get_full_pkg_versions && STEP="Install st2"
    sudo apt-get install -y st2${ST2_PKG_VERSION}
  else
    sudo apt-get install -y jq

    PACKAGE_URL=$(get_package_url "${DEV_BUILD}" "${SUBTYPE}" "st2_.*.deb")
    PACKAGE_FILENAME="$(basename ${PACKAGE_URL})"
    curl -sSL -k -o ${PACKAGE_FILENAME} ${PACKAGE_URL}
    sudo dpkg -i --force-depends ${PACKAGE_FILENAME}
    sudo apt-get install -yf
    rm ${PACKAGE_FILENAME}
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
  # Install htpasswd tool for editing ini files
  sudo apt-get install -y apache2-utils

  # Create a user record in a password file.
  sudo echo "${PASSWORD}" | sudo htpasswd -i /etc/st2/htpasswd $USERNAME

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
  sudo apt-key adv --fetch-keys http://nginx.org/keys/nginx_signing.key
  sudo sh -c "cat <<EOT > /etc/apt/sources.list.d/nginx.list
deb http://nginx.org/packages/ubuntu/ ${SUBTYPE} nginx
deb-src http://nginx.org/packages/ubuntu/ ${SUBTYPE} nginx
EOT"
  sudo apt-get update

  # Install st2web and nginx
  sudo apt-get install -y st2web${ST2WEB_PKG_VERSION} nginx

  # Generate self-signed certificate or place your existing certificate under /etc/ssl/st2
  sudo mkdir -p /etc/ssl/st2
  sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
  -days 365 -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information \
  Technology/CN=$(hostname)"

  # Remove default site, if present
  sudo rm -f /etc/nginx/conf.d/default.conf
  # Copy and enable StackStorm's supplied config file
  sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/conf.d/

  sudo service nginx restart
}

install_st2chatops() {
  # Update certificates
  sudo apt-get update
  sudo apt-get install -y ca-certificates

  # Add NodeJS 10 repo
  curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -

  # Install st2chatops
  sudo apt-get install -y st2chatops${ST2CHATOPS_PKG_VERSION}
}

configure_st2chatops() {
  # set API keys. This should work since CLI is configuered already.
  ST2_API_KEY=`st2 apikey create -k`
  sudo sed -i -r "s/^(export ST2_API_KEY.).*/\1$ST2_API_KEY/" /opt/stackstorm/chatops/st2chatops.env

  sudo sed -i -r "s/^(export ST2_AUTH_URL.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
  sudo sed -i -r "s/^(export ST2_AUTH_USERNAME.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
  sudo sed -i -r "s/^(export ST2_AUTH_PASSWORD.).*/# &/" /opt/stackstorm/chatops/st2chatops.env

  # Setup adapter
  if [[ "$HUBOT_ADAPTER"="slack" ]] && [[ ! -z "$HUBOT_SLACK_TOKEN" ]]
  then
    sudo sed -i -r "s/^# (export HUBOT_ADAPTER=slack)/\1/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^# (export HUBOT_SLACK_TOKEN.).*/\1/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export HUBOT_ADAPTER.).*/\1$HUBOT_ADAPTER/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export HUBOT_SLACK_TOKEN.).*/\1$HUBOT_SLACK_TOKEN/" /opt/stackstorm/chatops/st2chatops.env

    sudo service st2chatops restart
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


## Let's do this!

trap 'fail' EXIT
STEP="Setup args" && setup_args $@
STEP="Check TCP ports and MongoDB storage requirements" && check_st2_host_dependencies
STEP="Generate random password" && generate_random_passwords
STEP="Configure Proxy" && configure_proxy
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
