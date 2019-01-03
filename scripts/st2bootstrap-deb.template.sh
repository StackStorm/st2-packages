set -eu

HUBOT_ADAPTER='slack'
HUBOT_SLACK_TOKEN=${HUBOT_SLACK_TOKEN:-''}
VERSION=''
RELEASE='stable'
REPO_TYPE=''
REPO_PREFIX=''
ST2_PKG_VERSION=''
ST2MISTRAL_PKG_VERSION=''
ST2WEB_PKG_VERSION=''
ST2CHATOPS_PKG_VERSION=''
DEV_BUILD=''
USERNAME=''
PASSWORD=''
SUBTYPE=`lsb_release -a 2>&1 | grep Codename | grep -v "LSB" | awk '{print $2}'`

if [[ "$SUBTYPE" != 'trusty' && "$SUBTYPE" != 'xenial' && "$SUBTYPE" != 'bionic' ]]; then
  echo "Unsupported ubuntu flavor ${SUBTYPE}. Please use 14.04 (trusty), 16.04 (xenial) or Ubuntu 18.04 (bionic) as base system!"
  exit 2
fi


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

   # Right now Bionic is not officially supported yet so we only support using staging unstable packages
  if [[ "$SUBTYPE" == 'bionic' ]] && [[ "${DEV_BUILD}" = "" ]]; then
    if [[ "${REPO_TYPE}" != "staging" ]]; then
      echo "Ubuntu 18.04 (Bionic) is not officially supported yet and only staging unstable (--staging --unstable) packages can be used on Bionic"
      exit 2
    fi

    if [[ "${RELEASE}" != "unstable" ]]; then
      echo "Ubuntu 18.04 (Bionic) is not officially supported yet and only staging unstable (--staging --unstable) packages can be used on Bionic"
      exit 2
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
  sudo apt-get update

  # Note: gnupg-curl is needed to be able to use https transport when fetching keys
  if [[ "$SUBTYPE" != 'bionic' ]]; then
    sudo apt-get install -y gnupg-curl
  fi

  sudo apt-get install -y curl
  sudo apt-get install -y rabbitmq-server

  # Configure RabbitMQ to listen on localhost only
  sudo sh -c 'echo "RABBITMQ_NODE_IP_ADDRESS=127.0.0.1" >> /etc/rabbitmq/rabbitmq-env.conf'

  if [[ "$SUBTYPE" == 'xenial' || "${SUBTYPE}" == "bionic" ]]; then
    sudo systemctl restart rabbitmq-server
  else
    sudo service rabbitmq-server restart
  fi

  # Various other dependencies needed by st2 and installer script
  sudo apt-get install -y crudini
}

install_mongodb() {
  # Add key and repo for the latest stable MongoDB (3.4)
  # TODO: Install MongoDB 4.0 on Bionic
  if [[ "$SUBTYPE" == 'bionic' ]]; then
    wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | sudo apt-key add -
    echo "deb http://repo.mongodb.org/apt/ubuntu ${SUBTYPE}/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
  else
    wget -qO - https://www.mongodb.org/static/pgp/server-3.4.asc | sudo apt-key add -
    echo "deb http://repo.mongodb.org/apt/ubuntu ${SUBTYPE}/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  fi

  sudo apt-get update
  sudo apt-get install -y mongodb-org

  # Configure MongoDB to listen on localhost only
  sudo sed -i -e "s#bindIp:.*#bindIp: 127.0.0.1#g" /etc/mongod.conf

  if [[ "$SUBTYPE" == 'xenial' || "${SUBTYPE}" == "bionic" ]]; then
    sudo systemctl enable mongod
    sudo systemctl start mongod
  else
    sudo service mongod restart
  fi

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
  sudo sh -c 'echo "security:\n  authorization: enabled" >> /etc/mongod.conf'

  # MongoDB needs to be restarted after enabling auth
  if [[ "$SUBTYPE" == 'xenial'  || "${SUBTYPE}" == "bionic" ]]; then
    sudo systemctl restart mongod
  else
    sudo service mongod restart
  fi

}

get_full_pkg_versions() {
  if [ "$VERSION" != '' ];
  then
    local ST2_VER=$(apt-cache show st2 | grep Version | awk '{print $2}' | grep ^${VERSION//./\\.} | sort --version-sort | tail -n 1)
    if [ -z "$ST2_VER" ]; then
      echo "Could not find requested version of StackStorm!!!"
      sudo apt-cache policy st2
      exit 3
    fi

    if [[ "$SUBTYPE" != 'bionic' ]]; then
        # Bionic doesn't support Mistral
        local ST2MISTRAL_VER=$(apt-cache show st2mistral | grep Version | awk '{print $2}' | grep ^${VERSION//./\\.} | sort --version-sort | tail -n 1)

        if [ -z "$ST2MISTRAL_VER" ]; then
          echo "Could not find requested version of st2mistral!!!"
          sudo apt-cache policy st2mistral
          exit 3
        fi
     else
        local ST2MISTRAL_VER="none"
    fi

    local ST2WEB_VER=$(apt-cache show st2web | grep Version | awk '{print $2}' | grep ^${VERSION//./\\.} | sort --version-sort | tail -n 1)
    if [ -z "$ST2WEB_VER" ]; then
      echo "Could not find requested version of st2web."
      sudo apt-cache policy st2web
      exit 3
    fi

    local ST2CHATOPS_VER=$(apt-cache show st2chatops | grep Version | awk '{print $2}' | grep ^${VERSION//./\\.} | sort --version-sort | tail -n 1)
    if [ -z "$ST2CHATOPS_VER" ]; then
      echo "Could not find requested version of st2chatops."
      sudo apt-cache policy st2chatops
      exit 3
    fi

    ST2_PKG_VERSION="=${ST2_VER}"
    ST2MISTRAL_PKG_VERSION="=${ST2MISTRAL_VER}"
    ST2WEB_PKG_VERSION="=${ST2WEB_VER}"
    ST2CHATOPS_PKG_VERSION="=${ST2CHATOPS_VER}"
    echo "##########################################################"
    echo "#### Following versions of packages will be installed ####"
    echo "st2${ST2_PKG_VERSION}"
    echo "st2mistral${ST2MISTRAL_PKG_VERSION}"
    echo "st2web${ST2WEB_PKG_VERSION}"
    echo "st2chatops${ST2CHATOPS_PKG_VERSION}"
    echo "##########################################################"
  fi
}

install_st2() {
  # Following script adds a repo file, registers gpg key and runs apt-get update
  curl -s https://packagecloud.io/install/repositories/StackStorm/${REPO_PREFIX}${RELEASE}/script.deb.sh | sudo bash

  # 'mistral' repo builds single 'st2mistral' package and so we have to install 'st2' from repo
  if [ "$DEV_BUILD" = '' ] || [[ "$DEV_BUILD" =~ ^mistral/.* ]]; then
    STEP="Get package versions" && get_full_pkg_versions && STEP="Install st2"
    sudo apt-get install -y st2${ST2_PKG_VERSION}
  else
    sudo apt-get install -y jq

    PACKAGE_URL=$(get_package_url "${DEV_BUILD}" "${SUBTYPE}" "st2_.*.deb")
    PACKAGE_FILENAME="$(basename ${PACKAGE_URL})"
    curl -Ss -k -o ${PACKAGE_FILENAME} ${PACKAGE_URL}
    sudo dpkg -i --force-depends ${PACKAGE_FILENAME}
    sudo apt-get install -yf
    rm ${PACKAGE_FILENAME}
  fi

  # Configure [database] section in st2.conf (username password for MongoDB access)
  sudo crudini --set /etc/st2/st2.conf database username "stackstorm"
  sudo crudini --set /etc/st2/st2.conf database password "${ST2_MONGODB_PASSWORD}"

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

  sudo st2ctl restart-component st2api
  sudo st2ctl restart-component st2stream
}

install_st2mistral_dependencies() {
  sudo apt-get install -y postgresql

  # Configure service only listens on localhost
  sudo crudini --set /etc/postgresql/*/main/postgresql.conf '' listen_addresses "'127.0.0.1'"

  sudo service postgresql restart
  cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD '${ST2_POSTGRESQL_PASSWORD}';
CREATE DATABASE mistral OWNER mistral;
EHD
}

install_st2mistral() {
  # 'st2' repo builds single 'st2' package and so we have to install 'st2mistral' from repo
  if [ "$DEV_BUILD" = '' ] || [[ "$DEV_BUILD" =~ ^st2/.* ]]; then
    sudo apt-get install -y st2mistral${ST2MISTRAL_PKG_VERSION}
  else
    sudo apt-get install -y jq

    PACKAGE_URL=$(get_package_url "${DEV_BUILD}" "${SUBTYPE}" "st2mistral_.*.deb")
    PACKAGE_FILENAME="$(basename ${PACKAGE_URL})"
    curl -Ss -k -o ${PACKAGE_FILENAME} ${PACKAGE_URL}
    sudo dpkg -i --force-depends ${PACKAGE_FILENAME}
    sudo apt-get install -yf
    rm ${PACKAGE_FILENAME}
  fi

  # Configure database settings
  sudo crudini --set /etc/mistral/mistral.conf database connection "postgresql+psycopg2://mistral:${ST2_POSTGRESQL_PASSWORD}@127.0.0.1/mistral"

  # Setup Mistral DB tables, etc.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head

  # Register mistral actions.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate | grep -v openstack | grep -v "ironicclient"

  # Start Mistral
  sudo service mistral start
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
  # Add NodeJS 10 repo
  curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

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
  if [ "$HUBOT_ADAPTER"="slack" ] && [ ! -z "$HUBOT_SLACK_TOKEN" ]
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
STEP="Install st2 dependencies (MongoDB)" && install_mongodb
STEP="Install st2" && install_st2
STEP="Configure st2 user" && configure_st2_user
STEP="Configure st2 auth" && configure_st2_authentication
STEP="Configure st2 CLI config" && configure_st2_cli_config
STEP="Generate symmetric crypto key for datastore" && generate_symmetric_crypto_key_for_datastore
STEP="Verify st2" && verify_st2

if [[ "${SUBTYPE}" != "bionic" ]]; then
    STEP="Install mistral dependencies" && install_st2mistral_dependencies
    STEP="Install mistral" && install_st2mistral
fi

STEP="Install st2web" && install_st2web

STEP="Install st2chatops" && install_st2chatops
STEP="Configure st2chatops" && configure_st2chatops
trap - EXIT

ok_message
