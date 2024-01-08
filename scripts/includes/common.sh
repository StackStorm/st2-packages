
###This will ask user to create strong password containing one Upper case alphabet, one lower case alphabet, one digut and if it matches the criteria then only user will be given access to the installation.
set_password(){
  typeset PASSWORD
  regex="^(?=[a-zA-Z0-9#@!\-&+=\$\/?]{8,120}$)(?=.*?[a-z])(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[#@!\-&+=\$\/]).*"
  #echo $regex
  echo "******Please Note: Password should be at least 8 characters long with one digit, one Upper case Alphabet, one lower case alphabet and one special character ******"
  echo "Please enter password for User to be created: "
  read PASSWORD
  if [ "${PASSWORD}" = '' ]; then
      echo "Password cannot be empty."
      exit 1
  fi
  while ! echo "$PASSWORD" | grep -P "$regex"
  do
      echo "Enter password to match criteria"
      read PASSWORD 
  done
}

function configure_proxy() {
  # Allow bypassing 'proxy' env vars via sudo
  local sudoers_proxy='Defaults env_keep += "http_proxy https_proxy no_proxy proxy_ca_bundle_path DEBIAN_FRONTEND"'
  if ! sudo grep -s -q ^"${sudoers_proxy}" /etc/sudoers.d/st2; then
    sudo sh -c "echo '${sudoers_proxy}' >> /etc/sudoers.d/st2"
  fi

  # Configure proxy env vars for 'st2api', 'st2actionrunner' and 'st2chatops' system configs
  # See: https://docs.stackstorm.com/packs.html#installing-packs-from-behind-a-proxy
  local service_config_path=$(hash apt-get >/dev/null 2>&1 && echo '/etc/default' || echo '/etc/sysconfig')
  for service in st2api st2actionrunner st2chatops; do
    service_config="${service_config_path}/${service}"
    # create file if doesn't exist yet
    sudo test -e ${service_config} || sudo touch ${service_config}
    for env_var in http_proxy https_proxy no_proxy proxy_ca_bundle_path; do
      # delete line from file if specific proxy env var is unset
      if sudo test -z "${!env_var:-}"; then
        sudo sed -i "/^${env_var}=/d" ${service_config}
      # add proxy env var if it doesn't exist yet
      elif ! sudo grep -s -q ^"${env_var}=" ${service_config}; then
        sudo sh -c "echo '${env_var}=${!env_var}' >> ${service_config}"
      # modify existing proxy env var value
      elif ! sudo grep -s -q ^"${env_var}=${!env_var}$" ${service_config}; then
        sudo sed -i "s#^${env_var}=.*#${env_var}=${!env_var}#" ${service_config}
      fi
    done
  done
}

function get_package_url() {
  # Retrieve direct package URL for the provided dev build, subtype and package name regex.
  DEV_BUILD=$1 # Repo name and build number - <repo name>/<build_num> (e.g. st2/5646)
  DISTRO=$2  # Distro name (e.g. bionic,focal,el7,el8)
  PACKAGE_NAME_REGEX=$3

  PACKAGES_METADATA=$(curl -sSL -q https://circleci.com/api/v1.1/project/github/StackStorm/${DEV_BUILD}/artifacts)

  if [ -z "${PACKAGES_METADATA}" ]; then
      echo "Failed to retrieve packages metadata from https://circleci.com/api/v1.1/project/github/StackStorm/${DEV_BUILD}/artifacts" 1>&2
      return 2
  fi

  PACKAGES_URLS="$(echo ${PACKAGES_METADATA}  | jq -r '.[].url')"
  PACKAGE_URL=$(echo "${PACKAGES_URLS}" | egrep "${DISTRO}/${PACKAGE_NAME_REGEX}")

  if [ -z "${PACKAGE_URL}" ]; then
      echo "Failed to find url for ${DISTRO} package (${PACKAGE_NAME_REGEX})" 1>&2
      echo "Circle CI response: ${PACKAGES_METADATA}" 1>&2
      return 2
  fi

  echo ${PACKAGE_URL}
}


function port_status() {
  # If the specified tcp4 port is bound, then return the "port pid/procname",
  # else if a pipe command fails, return "Unbound",
  # else return "".
  #
  # Please note that all return values end with a newline.
  #
  # Use netstat and awk to get a list of all the tcp4 sockets that are in the LISTEN state,
  # matching the specified port.
  #
  # The `netstat -tunlp --inet` command is assumed to output data in the following format:
  #   Active Internet connections (only servers)
  #   Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
  #   tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      7506/httpd
  #
  # The awk command prints the 4th and 7th columns of any line matching both the following criteria:
  #   1) The 4th column contains the port passed to port_status()  (i.e., $1)
  #   2) The 6th column contains "LISTEN"
  #
  # Sample output:
  #   0.0.0.0:25000 7506/sshd
  ret=$(sudo netstat -tunlp --inet | awk -v port=":$1$" '$4 ~ port && $6 ~ /LISTEN/ { print $4 " " $7 }' || echo 'Unbound');
  echo "$ret";
}


check_st2_host_dependencies() {
  # CHECK 1: Determine which, if any, of the required ports are used by an existing process.

  # Abort the installation early if the following ports are being used by an existing process.
  # nginx (80, 443), mongodb (27017), rabbitmq (4369, 5672, 25672), redis (6379)
  # and st2 (9100-9102).

  declare -a ports=("80" "443" "4369" "5672" "6379" "9100" "9101" "9102" "25672" "27017")
  declare -a used=()

  for i in "${ports[@]}"
  do
    rv=$(port_status $i | sed 's/.*-$\|.*systemd\|.*beam.smp.*\|.*epmd\|.*st2.*\|.*nginx.*\|.*python.*\|.*postmaster.*\|.*mongod\|.*init//')
    if [ "$rv" != "Unbound" ] && [ "$rv" != "" ]; then
      used+=("$rv")
    fi
  done

  # If any used ports were found, display helpful message and exit
  if [ ${#used[@]} -gt 0 ]; then
    printf "\nNot all required TCP ports are available. ST2 and related services will fail to start.\n\n"
    echo "The following ports are in use by the specified pid/process and need to be stopped:"
    for port_pid_process in "${used[@]}"
    do
       echo " $port_pid_process"
    done
    echo ""
    exit 1
  fi

  # CHECK 2: Ensure there is enough space at /var/lib/mongodb
  VAR_SPACE=`df -Pk /var/lib | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{print $4}'`
  if [ ${VAR_SPACE} -lt 358400 ]; then
    echo ""
    echo "MongoDB requires at least 350MB free in /var/lib/mongodb"
    echo "There is not enough space for MongoDB. It will fail to start."
    echo "Please, add some space to /var or clean it up."
    exit 1
  fi
}


generate_random_passwords() {
  # Generate random password used for MongoDB user authentication
  ST2_MONGODB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo '')
  # Generate random password used for RabbitMQ user authentication
  ST2_RABBITMQ_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo '')
}


configure_st2_user () {
  # Create an SSH system user (default `stanley` user may be already created)
  if (! id stanley 2>/dev/null); then
    sudo useradd stanley
  fi

  SYSTEM_HOME=$(echo ~stanley)

  if [ ! -d "${SYSTEM_HOME}/.ssh" ]; then
    sudo mkdir ${SYSTEM_HOME}/.ssh
    sudo chmod 700 ${SYSTEM_HOME}/.ssh
  fi

  # Generate ssh keys on StackStorm box and copy over public key into remote box.
  # NOTE: If the file already exists and is non-empty, then assume the key does not need
  # to be generated again.
  if ! sudo test -s ${SYSTEM_HOME}/.ssh/stanley_rsa; then
    # added PEM to enforce PEM ssh key type in EL8 to maintain consistency
    sudo ssh-keygen -f ${SYSTEM_HOME}/.ssh/stanley_rsa -P "" -m PEM
  fi

  if ! sudo grep -s -q -f ${SYSTEM_HOME}/.ssh/stanley_rsa.pub ${SYSTEM_HOME}/.ssh/authorized_keys;
  then
    # Authorize key-base access
    sudo sh -c "cat ${SYSTEM_HOME}/.ssh/stanley_rsa.pub >> ${SYSTEM_HOME}/.ssh/authorized_keys"
  fi

  sudo chmod 0600 ${SYSTEM_HOME}/.ssh/authorized_keys
  sudo chmod 0700 ${SYSTEM_HOME}/.ssh
  sudo chown -R stanley:stanley ${SYSTEM_HOME}

  # Enable passwordless sudo
  local STANLEY_SUDOERS="stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL"
  if ! sudo grep -s -q ^"${STANLEY_SUDOERS}" /etc/sudoers.d/st2; then
    sudo sh -c "echo '${STANLEY_SUDOERS}' >> /etc/sudoers.d/st2"
  fi

  sudo chmod 0440 /etc/sudoers.d/st2

  # Disable requiretty for all users
  sudo sed -i -r "s/^Defaults\s+\+?requiretty/# Defaults requiretty/g" /etc/sudoers
}


configure_st2_cli_config() {
  # Configure CLI config (write credentials for the root user and user which ran the script)
  ROOT_USER="root"
  CURRENT_USER=$(whoami)

  ROOT_HOME=$(eval echo ~${ROOT_USER})
  : "${HOME:=$(eval echo ~${CURRENT_USER})}"

  ROOT_USER_CLI_CONFIG_DIRECTORY="${ROOT_HOME}/.st2"
  ROOT_USER_CLI_CONFIG_PATH="${ROOT_USER_CLI_CONFIG_DIRECTORY}/config"

  CURRENT_USER_CLI_CONFIG_DIRECTORY="${HOME}/.st2"
  CURRENT_USER_CLI_CONFIG_PATH="${CURRENT_USER_CLI_CONFIG_DIRECTORY}/config"

  if ! sudo test -d ${ROOT_USER_CLI_CONFIG_DIRECTORY}; then
    sudo mkdir -p ${ROOT_USER_CLI_CONFIG_DIRECTORY}
  fi

  sudo sh -c "cat <<EOT > ${ROOT_USER_CLI_CONFIG_PATH}
[credentials]
username = ${USERNAME}
password = ${PASSWORD}
EOT"

  # Write config for root user
  if [ "${CURRENT_USER}" == "${ROOT_USER}" ]; then
      return
  fi

  # Write config for current user (in case current user != root)
  if [ ! -d ${CURRENT_USER_CLI_CONFIG_DIRECTORY} ]; then
    sudo mkdir -p ${CURRENT_USER_CLI_CONFIG_DIRECTORY}
  fi

  sudo sh -c "cat <<EOT > ${CURRENT_USER_CLI_CONFIG_PATH}
[credentials]
username = ${USERNAME}
password = ${PASSWORD}
EOT"

  # Fix the permissions
  sudo chown -R ${CURRENT_USER}:${CURRENT_USER} ${CURRENT_USER_CLI_CONFIG_DIRECTORY}
}


generate_symmetric_crypto_key_for_datastore() {
  DATASTORE_ENCRYPTION_KEYS_DIRECTORY="/etc/st2/keys"
  DATASTORE_ENCRYPTION_KEY_PATH="${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}/datastore_key.json"

  sudo mkdir -p ${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}

  # If the file ${DATASTORE_ENCRYPTION_KEY_PATH} exists and is not empty, then do not generate
  # a new key. st2-generate-symmetric-crypto-key fails if the key file already exists.
  if ! sudo test -s ${DATASTORE_ENCRYPTION_KEY_PATH}; then
    sudo st2-generate-symmetric-crypto-key --key-path ${DATASTORE_ENCRYPTION_KEY_PATH}
  fi

  # Make sure only st2 user can read the file
  sudo chgrp st2 ${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}
  sudo chmod o-r ${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}
  sudo chgrp st2 ${DATASTORE_ENCRYPTION_KEY_PATH}
  sudo chmod o-r ${DATASTORE_ENCRYPTION_KEY_PATH}

  # set path to the key file in the config
  sudo crudini --set /etc/st2/st2.conf keyvalue encryption_key_path ${DATASTORE_ENCRYPTION_KEY_PATH}

  # NOTE: We need to restart all the affected services so they pick the key and load it in memory
  sudo st2ctl restart-component st2api
  sudo st2ctl restart-component st2sensorcontainer
  sudo st2ctl restart-component st2workflowengine
  sudo st2ctl restart-component st2actionrunner
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
  st2 pack install st2
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
  echo "* Pack Exchange - https://exchange.stackstorm.org/"
  echo ""
  echo "Thanks for installing StackStorm! Come visit us in our Slack Channel"
  echo "and tell us how it's going. We'd love to hear from you!"
  echo "http://stackstorm.com/community-signup"
}


fail() {
  echo "############### ERROR ###############"
  echo "# Failed on $STEP #"
  echo "#####################################"
  exit 2
}
