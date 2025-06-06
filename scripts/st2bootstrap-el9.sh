#!/usr/bin/env bash
#
#

set -e -u +x

HUBOT_ADAPTER='slack'
HUBOT_SLACK_BOT_TOKEN=${HUBOT_SLACK_BOT_TOKEN:-''}
HUBOT_SLACK_APP_TOKEN=${HUBOT_SLACK_APP_TOKEN:-''}
VERSION=''
RELEASE='stable'
REPO_TYPE=''
DEV_BUILD=''
USERNAME=''
PASSWORD=''
ST2_PKG='st2'
ST2WEB_PKG='st2web'
ST2CHATOPS_PKG='st2chatops'
INSTALL_MONGODB=1
INSTALL_RABBITMQ=1
INSTALL_REDIS=1
INSTALL_ST2CHATOPS=1
INSTALL_ST2WEB=1

declare -A INSTALL_TYPE=()

source <(sed 's/^/OS_/g' /etc/os-release)

usage() {
    cat <<EOF

    $0 [--version=<x.y.z|x.ydev>] [--stable|--unstable] [--staging] [--dev=<repo_name/build_num>] [--user=<st2username>] [--password=<st2password>]
       [--no-mongodb] [--no-rabbitmq] [--no-redis] [--no-st2chatops] [--no-st2web]

    StackStorm installation script.  This script will configure and install StackStorm and its dependencies on the system.
    WARNING: This script will make system changes that aren't automatically reversible.

    Parameters
        --version|-v:   The StackStorm version to be installed.
                        Stable versions are <major>.<minor>.<patch>. E.g. --version=3.8.1 to install StackStorm v3.8.1 from the stable repository.
                        Unstable versions are <major>.<minor>dev.  E.g. --version=3.9dev to install the latest StackStorm v3.9dev from the unstable repository.

        --username:     The StackStorm account name to be created.

        --password:     The password for the StackStorm account.

        --stable|-s:    Install StackStorm packages from the stable repository. (default)
                        Packages are officially supported and production ready.
                        The stable option is mutually exclusive with the unstable option.

        --unstable|-u:  Install StackStorm packages from the unstable repository.
                        Daily or Promoted packages built after passing end-to-end testing from the StackStorm development branch.

        --staging:      Install StackStorm packages from the staging-<stable|unstable> repository.
                        This option is combined with the stable/unstable option.
                        staging-stable packages are release candidate made available for testing during the StackStorm release process.
                        staging-unstable experimental packages that are built from the latest development branch that have passed unit testing.

        --dev=*:        Install StackStorm from Continuous Integration artifact.
                        The pamameter takes the git repository name and build number - <repo_name>/<build_num>.  E.g. --dev=st2/5646
                        Do not use this option unless you understand what you're doing.

        --no-mongodb    Disable the installation procedure for MongoDB on the system.

        --no-rabbitmq   Disable the installation procedure for RabbitMQ on the system.

        --no-redis      Disable the installation procedure for Redis on the system.

        --no-st2chatops Disable the installation procedure for st2 chatops on the system.

        --no-st2web     Disable the installation procedure for st2 web ui on the system.

EOF
}
function centre()
{
    LINE_LEN="$1"
    TEXT="$2"
    OUTPUT=""
    
    if [[ ${#TEXT} -lt ${LINE_LEN} ]]; then
        LS=$(( (LINE_LEN - ${#TEXT}) / 2 ))
        OUTPUT+=$(printf "%0.s " $(seq 0 $LS))
        OUTPUT+="$TEXT"
        RS=$(( LINE_LEN - ${#OUTPUT} ))
        OUTPUT+=$(printf "%0.s " $(seq 0 $RS))
    fi
    
    echo "${OUTPUT}"
}
function cecho()
{
    if [[ "$1" == "-n" ]]; then
        local NCR="$1"; shift
    else
        local NCR=""
    fi
    local C="$1";
    local MSG="$2"
    echo $NCR -e "${C}${MSG}\e[0m"
}
function heading()
{
    local COLS=$(stty size | cut -d' ' -f2)
    if [[ -n "$COLS" ]]; then
        HEADING=$(centre $((COLS - 1)) "$1")
    else
        HEADING="$1"
    fi
    echo
    cecho "\e[38;5;208m\e[48;5;238m\e[1m" "$HEADING"
    echo
}
function echo.info()
{
    cecho "\e[37;1m" "$1"
}
function echo.warning()
{
    cecho "\e[33;1m" "$1"
}
function echo.error()
{
    cecho "\e[31;1m" "$1" >/dev/stderr
}
setup_install_parameters()
{
    local VERSION="$1"
    local RELEASE="$2"
    local REPO_TYPE="$3"
    local DEV_BUILD="$4"

    if [[ -n "$DEV_BUILD" ]]; then
        INSTALL_TYPE["CI"]="$DEV_BUILD"
        if [[ ! "$DEV_BUILD" =~ [^/]+/[0-9]+ ]]; then
            echo.error "Unexpected format '$DEV_BUILD'.  Format must be 'repo_name/build_id'"
            exit 1
        fi
        echo.warning "Installation of $DEV_BUILD from CI build artifacts!  REALLY, ANYTHING COULD HAPPEN!"
    else
        setup_select_repository "$VERSION" "$RELEASE" "$REPO_TYPE"
    fi
}


setup_check_version()
{
    local VERSION="$1"
    if [[ -z "$VERSION" ]]; then
        echo.error "Unable to run script because no StackStorm version was provided."
        usage
        exit 1
    fi
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
        echo.error "$VERSION does not match supported formats x.y.z or x.ydev."
        exit 1
    fi
}


setup_select_repository()
{
    local VERSION="$1"
    local RELEASE="$2"
    local REPO_TYPE="$3"

    setup_check_version "$VERSION"

    if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
        if [[ "$RELEASE" != "unstable" ]]; then
            echo.warning "Development version $VERSION requested, switching from '$RELEASE' to 'unstable' repository!"
            RELEASE='unstable'
        fi
    fi

    if [[ -n "$REPO_TYPE" ]]; then
        echo.warning "Installing from staging repository:  USE AT YOUR OWN RISK!"
        RELEASE="${REPO_TYPE}-${RELEASE}"
    fi
    echo.info "Installation of StackStorm $VERSION from repository $RELEASE."
    INSTALL_TYPE["REPO"]="$RELEASE"
}


setup_username_password()
{
    if [[ "$USERNAME" = '' || "$PASSWORD" = '' ]]; then
        echo "Let's set StackStorm admin credentials."
        echo 'You can also use "--user" and "--password" for unattended installation.'
        echo 'Press <ENTER> to continue or <CTRL+C> to exit/abort.'
        read -e -p "Admin username: " -i "st2admin" USERNAME
        read -e -s -p "Password: " PASSWORD
        echo
        if [[ -z "${PASSWORD}" ]]; then
            echo.error "Password cannot be empty."
            exit 1
        fi
    fi
}
pkg_install()
{
    
    sudo dnf -y install $@
}

pkg_meta_update()
{
    
    sudo dnf -y check-update
    
}

pkg_is_installed()
{
    PKG="$1"
    
    sudo rpm -q "$PKG" | grep -qE "^${PKG}"
    
}


pkg_get_latest_version()
{
    local PKG="$1" # st2
    local VERSION="$2" # 3.9dev
    LATEST=$(repoquery -y --nvr --show-duplicates "$PKG" | grep -F "${PKG}-${VERSION}" | sort --version-sort | tail -n 1)
    echo "${LATEST#*-}"
}


repo_add_gpg_key()
{
    KEY_NAME="$1"
    KEY_URL="$2"
    rpm --import "${KEY_URL}"
}


repo_definition()
{
    REPO_NAME="$1"
    REPO_URL="$2"
    KEY_NAME="$3"
    KEY_URL="$4"
    REPO_PATH="/etc/yum.repos.d/"

    cat <<EOF >"${REPO_PATH}/${REPO_NAME}.repo"
[${REPO_NAME}]
name=${REPO_NAME}
baseurl=${REPO_URL}
repo_gpgcheck=1
enabled=1
gpgkey=${KEY_URL}
gpgcheck=0
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md
EOF
}


pkg_get_versions()
{
    dnf -y info --showduplicates "$1"
}


repo_clean_meta()
{
    dnf -y clean metadata
    dnf -y clean dbcache
    dnf -y clean all
}


repo_pkg_availability() {
    local PKG="$1"
    local VERSION="$2"

    local PKG_VER=""
    
        PKG_VER=$(pkg_get_latest_version "$PKG" "${VERSION}")
    

    if [[ -z "$PKG_VER" ]]; then
        echo.error "${PKG}-${VERSION} couldn't be found in the pacakges available on this system."
        exit 3
    fi
    echo "$PKG_VER"
}
system_install_runtime_packages()
{
    
    if ! pkg_is_installed epel-release; then
        pkg_install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    fi
    
    local PKG_DEPS=(
        crudini
        curl
        jq
        logrotate
        net-tools
        yum-utils
        iproute
        gnupg2
        httpd-tools
        )
    pkg_meta_update
    pkg_install ${PKG_DEPS[@]}
}


system_configure_proxy()
{
    local sudoers_proxy='Defaults env_keep += "http_proxy https_proxy no_proxy proxy_ca_bundle_path DEBIAN_FRONTEND"'
    if ! sudo grep -s -q ^"${sudoers_proxy}" /etc/sudoers.d/st2; then
        sudo sh -c "echo '${sudoers_proxy}' >> /etc/sudoers.d/st2"
    fi

    service_config_path=""
    for cfgdir in "/etc/sysconfig" "/etc/default"
    do
        if [[ -d "$cfgdir" ]]; then
            service_config_path="$cfgdir"
            break
        fi
    done

    if [[ -z "$service_config_path" ]]; then
        echo.error "Failed to determine the systems configuration path!  Is this system supported?"
        exit 1
    fi
    for service in st2api st2actionrunner st2chatops;
    do
        service_config="${service_config_path}/${service}"
        sudo test -e "${service_config}" || sudo touch "${service_config}"
        for env_var in http_proxy https_proxy no_proxy proxy_ca_bundle_path; do
            if sudo test -z "${!env_var:-}"; then
                sudo sed -i "/^${env_var}=/d" ${service_config}
            elif ! sudo grep -s -q ^"${env_var}=" ${service_config}; then
                sudo sh -c "echo '${env_var}=${!env_var}' >> ${service_config}"
            elif ! sudo grep -s -q ^"${env_var}=${!env_var}$" ${service_config}; then
                sudo sed -i "s#^${env_var}=.*#${env_var}=${!env_var}#" ${service_config}
            fi
        done
    done
}


system_port_status()
{
    #
    #
    #

    #
    sudo ss -ltpun4 "sport = :$1" | awk '/tcp.*LISTEN.*/ {print $5" "$7}' || echo "Unbound"
}


system_check_resources()
{

    PORT_TEST=$(
    cat <<EOF
    {
        "nginx": {
            "ports": [80, 443],
            "process": ".*nginx.*"
        },
        "redis": {
            "ports": [6379],
            "process": ".*redis-server.*"
        },
        "mongodb": {
            "ports": [27017],
            "process": ".*mongod.*"
        },
        "st2": {
            "ports": [9100, 9101, 9102],
            "process": ".*gunicorn.*"
        },
        "rabbitmq": {
            "ports": [5672, 25672],
            "process": ".*beam.smp.*"
        },
        "erlang": {
            "ports": [4369],
            "process": ".*epmd.*"
        }
    }
EOF
)
    declare -a used=()
    for test in $(jq -r '. | keys[]' <<<$PORT_TEST); do
        ALLOWED=$(jq -r '.'"$test"'.process' <<<$PORT_TEST)
        for i in $(jq -r '.'"$test"'.ports[]' <<<$PORT_TEST)
        do
            rv="$(system_port_status $i | sed 's/.*-$\|'${ALLOWED}'//')"
            if [[ "$rv" != "Unbound" ]] && [[ -n "$rv" ]]; then
                used+=("$rv")
            fi
        done
    done

    if [[ ${#used[@]} -gt 0 ]]; then
        #
        echo.error "\nNot all required TCP ports are available. ST2 and related services will fail to start.\n\n"
        echo.info "The following ports are in use by the specified pid/process and need to be stopped:"
        for port_pid_process in "${used[@]}"
        do
             echo.info " $port_pid_process"
        done
        echo ""
        exit 1
    fi

    VAR_SPACE=`df -Pm /var/lib | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{print $4}'`
    if [[ ${VAR_SPACE} -lt 350 ]]; then
        echo
        echo.error "MongoDB disk space check failed."
        echo.info "MongoDB requires at least 350MB free in /var/lib/mongodb but the is only ${VAR_SPACE}MB available."
        echo.info "There is not enough space for MongoDB.  It will fail to start.  Please, add some space to /var or clean it up."
        exit 1
    fi
}


system_generate_password()
{
    local LEN="$1"
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c $LEN; echo ''
}


ok_message()
{
    cat <<EOF

                      StackStorm is installed and ready to use.
┌──────────────────┐
│   ▓▓▓▓▓  ███████ │  Head to https://YOUR_HOST_IP/ to access the WebUI
│ ▓▓▓▓▓▓▓▓▓  █████ │
│▓▓▓▓▓▓▓▓▓▓▓▓  ███ │  Don't forget to dive into our documentation! Here are some resources
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓ │  for you:
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │
│   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  * Documentation  - https://docs.stackstorm.com
│ ██  ▓▓▓▓▓▓▓▓▓▓▓▓▓│  * Pack Exchange - https://exchange.stackstorm.org/
│ ████  ▓▓▓▓▓▓▓▓▓▓ │
│ ███████  ▓▓▓▓▓▓  │  Thanks for installing StackStorm! Come visit us in our Slack Channel
└──────────────────┘  and tell us how it's going. We'd love to hear from you!
                      http://stackstorm.com/community-signup

                      Password credentials have been saved to /root/st2_credentials.
                      Please store them in a secure location and delete the file.


EOF
}

write_passwords()
{
    cat <<EOF >/root/st2_credentials
User account details:
  StackStorm
    username: $USERNAME
    password: $PASSWORD
  MongoDB
    username: admin
    password: $ST2_MONGODB_PASSWORD
  RabbitMQ
    username: stackstorm
    password: $ST2_RABBITMQ_PASSWORD
EOF
}

step()
{
    export STEP="$1"
    echo; heading "$STEP"; echo
}


fail()
{
    echo.error "Failed during '$STEP'"
    exit 2
}

st2_configure_repository()
{
    local REPO_TGT="$1"
    repo_definition "st2-${REPO_TGT}" \
                    "https://packagecloud.io/StackStorm/${REPO_TGT}/el/9/\$basearch/" \
                    "st2-${REPO_TGT}-key" \
                    "https://packagecloud.io/StackStorm/${REPO_TGT}/gpgkey"
}
st2_distribution_name()
{
    echo "el9"
}
st2_install_from_url()
{
    local PACKAGE_URL="$1"
    pkg_install "${PACKAGE_URL}"
}
st2_install_pkg_version()
{
    local PKG="$1"
    local VERSION="$2"
    pkg_install "${PKG}-${VERSION}"
}


st2_install_dev_build()
{
    DEV_BUILD="$1" # Repo name and build number - <repo name>/<build_num> (e.g. st2/5646)
    DISTRO="$(st2_distribution_name)"  # Distro name (e.g. focal, jammy, el8, el9)
    PACKAGE_NAME_REGEX="${DISTRO}/st2[_-].*\.(deb|rpm)$"
    MANIFEST_URL="https://circleci.com/api/v1.1/project/github/StackStorm/${DEV_BUILD}/artifacts"

    PACKAGES_METADATA=$(curl -sSL -q "$MANIFEST_URL" || true)
    if [[ -z "${PACKAGES_METADATA}" ]]; then
        echo.error "Failed to retrieve packages metadata from $MANIFEST_URL"
        exit 30
    fi

    ARTIFACT_URLS=$(jq -r '.[].url' <<<"$PACKAGES_METADATA" || true)
    if [[ -z "$ARTIFACT_URLS" ]]; then
        echo.error "No urls found in manifest.  This might be because the JSON structure changed or is invalid."
        exit 31
    fi

    PACKAGE_URL=$(grep -E "${PACKAGE_NAME_REGEX}" <<<"$ARTIFACT_URLS" || true)
    if [[ -z "${PACKAGE_URL}" ]]; then
        echo.error "Failed to find url for ${DISTRO} package (${PACKAGE_NAME_REGEX})"
        echo.error "Circle CI response: ${PACKAGES_METADATA}"
        exit 32
    fi
    echo.info "Installing CI artifact from ${PACKAGE_URL}"
    st2_install_from_url "$PACKAGE_URL"
}

st2_install()
{
    if [[ "${!INSTALL_TYPE[@]}" == "REPO" ]]; then
        st2_configure_repository "${INSTALL_TYPE[REPO]}"
        pkg_meta_update

        ST2_PKG_VERSION="$(repo_pkg_availability st2 $VERSION)"
        ST2WEB_PKG_VERSION="$(repo_pkg_availability st2web $VERSION)"
        ST2CHATOPS_PKG_VERSION="$(repo_pkg_availability st2chatops $VERSION)"

        echo.info "The following versions of packages will be installed"
        echo.info "  ${ST2_PKG_VERSION}"
        echo.info "  ${ST2WEB_PKG_VERSION}"
        echo.info "  ${ST2CHATOPS_PKG_VERSION}"
        st2_install_pkg_version st2 ${ST2_PKG_VERSION}

    elif [[ "${!INSTALL_TYPE[@]}" == "CI" ]]; then
        echo.info "Development build ${INSTALL_TYPE[CI]}"
        st2_install_dev_build "${INSTALL_TYPE[CI]}"
    else
        echo.error "Unknown installation type ${!INSTALL_TYPE[@]}."
        exit 3
    fi

    local ST2_CFGFILE="/etc/st2/st2.conf"

    local DB_URI="mongodb://stackstorm:${ST2_MONGODB_PASSWORD}@127.0.0.1:27017/st2?authSource=st2"
    sudo crudini --set "$ST2_CFGFILE" database host "$DB_URI"

    local AMQP="amqp://stackstorm:$ST2_RABBITMQ_PASSWORD@127.0.0.1:5672"
    sudo crudini --set "$ST2_CFGFILE" messaging url "${AMQP}"

    sudo crudini --set "$ST2_CFGFILE" coordination url "redis://127.0.0.1:6379"

    if [[ ! -d /var/log/st2 ]]; then
        echo.warning "Work around packging bug: create /var/log/st2"
        sudo mkdir -p /var/log/st2
        sudo chown st2 /var/log/st2
    fi
    sudo st2ctl reload --register-all
    sudo st2ctl restart
}


st2_configure_authentication() {
    local ST2_CFGFILE="/etc/st2/st2.conf"

    sudo htpasswd -i /etc/st2/htpasswd $USERNAME <<<"${PASSWORD}"

    sudo crudini --set "$ST2_CFGFILE" auth enable "True"
    sudo crudini --set "$ST2_CFGFILE" auth backend "flat_file"
    sudo crudini --set "$ST2_CFGFILE" auth backend_kwargs '{"file_path": "/etc/st2/htpasswd"}'

    for srv in st2auth st2api st2stream
    do
        sudo st2ctl restart-component $srv
    done
}


st2_configure_user()
{
    if (! id stanley 2>/dev/null); then
        sudo useradd stanley
    fi

    SYSTEM_HOME=$(echo ~stanley)

    if [ ! -d "${SYSTEM_HOME}/.ssh" ]; then
        sudo mkdir ${SYSTEM_HOME}/.ssh
        sudo chmod 700 ${SYSTEM_HOME}/.ssh
    fi

    if ! sudo test -s ${SYSTEM_HOME}/.ssh/stanley_rsa; then
        sudo ssh-keygen -f ${SYSTEM_HOME}/.ssh/stanley_rsa -P "" -m PEM
    fi

    if ! sudo grep -s -q -f ${SYSTEM_HOME}/.ssh/stanley_rsa.pub ${SYSTEM_HOME}/.ssh/authorized_keys;
    then
        sudo sh -c "cat ${SYSTEM_HOME}/.ssh/stanley_rsa.pub >> ${SYSTEM_HOME}/.ssh/authorized_keys"
    fi

    sudo chmod 0600 ${SYSTEM_HOME}/.ssh/authorized_keys
    sudo chmod 0700 ${SYSTEM_HOME}/.ssh
    sudo chown -R stanley:stanley ${SYSTEM_HOME}

    local STANLEY_SUDOERS="stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL"
    if ! sudo grep -s -q ^"${STANLEY_SUDOERS}" /etc/sudoers.d/st2; then
        sudo sh -c "echo '${STANLEY_SUDOERS}' >> /etc/sudoers.d/st2"
    fi

    sudo chmod 0440 /etc/sudoers.d/st2

    sudo sed -i -r "s/^Defaults\s+\+?requiretty/# Defaults requiretty/g" /etc/sudoers
}


st2_configure_cli_config()
{
    local USERNAME="$1"
    local PASSWORD="$2"
    test -z "$USERNAME" && ( echo.error "Can't configure cli, missing username."; exit 9 )
    test -z "$PASSWORD" && ( echo.error "Can't configure cli, missing password."; exit 9 )

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

    sudo sh -c "cat <<EOF >${ROOT_USER_CLI_CONFIG_PATH}
[credentials]
username = ${USERNAME}
password = ${PASSWORD}
EOF"

    if [ "${CURRENT_USER}" == "${ROOT_USER}" ]; then
        return
    fi

    if [ ! -d ${CURRENT_USER_CLI_CONFIG_DIRECTORY} ]; then
        sudo mkdir -p ${CURRENT_USER_CLI_CONFIG_DIRECTORY}
    fi

    sudo sh -c "cat <<EOF > ${CURRENT_USER_CLI_CONFIG_PATH}
[credentials]
username = ${USERNAME}
password = ${PASSWORD}
EOF"

    sudo chown -R ${CURRENT_USER}:${CURRENT_USER} ${CURRENT_USER_CLI_CONFIG_DIRECTORY}
}


st2_setup_kvstore_encryption_keys()
{
    DATASTORE_ENCRYPTION_KEYS_DIRECTORY="/etc/st2/keys"
    DATASTORE_ENCRYPTION_KEY_PATH="${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}/datastore_key.json"

    sudo mkdir -p ${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}

    if ! sudo test -s ${DATASTORE_ENCRYPTION_KEY_PATH}; then
        sudo st2-generate-symmetric-crypto-key --key-path ${DATASTORE_ENCRYPTION_KEY_PATH}
    fi

    for dir in "${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}" "${DATASTORE_ENCRYPTION_KEY_PATH}"
    do
        sudo chgrp st2 "$dir"
        sudo chmod o-r "${dir}"
    done
    sudo crudini --set /etc/st2/st2.conf keyvalue encryption_key_path ${DATASTORE_ENCRYPTION_KEY_PATH}

    for srv in st2api st2sensorcontainer st2workflowengine st2actionrunner
    do
        sudo st2ctl restart-component $srv
    done
}


st2_verification()
{
    echo.info "Check version"
    st2 --version

    echo.info "Check help"
    st2 -h

    echo.info "Check Authentication"
    st2 auth $USERNAME -p $PASSWORD
    export ST2_AUTH_TOKEN=$(st2 auth $USERNAME -p $PASSWORD -t)

    echo.info "Check actions list for 'core' pack"
    st2 action list --pack=core

    echo.info "Check local shell command"
    st2 run core.local -- date -R

    echo.info "Check execution list"
    st2 execution list

    echo.info "Check remote comand via SSH (Requires passwordless SSH)"
    st2 run core.remote hosts='127.0.0.1' -- uname -a

    echo.info "Check pack installation"
    st2 pack install st2
}
nodejs_configure_repository()
{
    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo -E bash -
}

st2chatops_install()
{
    nodejs_configure_repository
    pkg_install nodejs

    st2_install_pkg_version st2chatops ${ST2CHATOPS_PKG_VERSION}
}

st2chatops_configure()
{
    ST2_API_KEY=$(st2 apikey create -k)
    sudo sed -i -r "s/^(export ST2_API_KEY.).*/\1$ST2_API_KEY/" /opt/stackstorm/chatops/st2chatops.env

    sudo sed -i -r "s/^(export ST2_AUTH_URL.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export ST2_AUTH_USERNAME.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export ST2_AUTH_PASSWORD.).*/# &/" /opt/stackstorm/chatops/st2chatops.env

    if [[ "$HUBOT_ADAPTER"="slack" ]] && [[ ! -z "$HUBOT_SLACK_BOT_TOKEN" ]] && [[ ! -z "$HUBOT_SLACK_APP_TOKEN" ]];
    then
        sudo sed -i -r "s/^# (export HUBOT_ADAPTER=slack)/\1/" /opt/stackstorm/chatops/st2chatops.env
        sudo sed -i -r "s/^# (export HUBOT_SLACK_BOT_TOKEN.).*/\1/" /opt/stackstorm/chatops/st2chatops.env
        sudo sed -i -r "s/^# (export HUBOT_SLACK_APP_TOKEN.).*/\1/" /opt/stackstorm/chatops/st2chatops.env
        sudo sed -i -r "s/^(export HUBOT_ADAPTER.).*/\1$HUBOT_ADAPTER/" /opt/stackstorm/chatops/st2chatops.env
        sudo sed -i -r "s/^(export HUBOT_SLACK_BOT_TOKEN.).*/\1$HUBOT_SLACK_BOT_TOKEN/" /opt/stackstorm/chatops/st2chatops.env
        sudo sed -i -r "s/^(export HUBOT_SLACK_APP_TOKEN.).*/\1$HUBOT_SLACK_APP_TOKEN/" /opt/stackstorm/chatops/st2chatops.env

        sudo service st2chatops restart
    else
        echo.warning "Warning: Chatops requires manual configuration!"
        echo.info "Edit /opt/stackstorm/chatops/st2chatops.env to specify"
        echo.info "the adapter and settings hubot should use to connect to"
        echo.info "the chat you're using.  Don't forget to start the service"
        echo.info "afterwards:"
        echo.info ""
        echo.info "  $ sudo systemctl restart st2chatops"
        echo.info ""
        echo.info "For more information, please refer to documentation at"
        echo.info "https://docs.stackstorm.com/install/index.html"
    fi
}
nginx_configure_repo()
{
    repo_definition "nginx" \
                    "http://nginx.org/packages/rhel/9/x86_64/" \
                    "nginx-key" \
                    "http://nginx.org/keys/nginx_signing.key"

}

st2web_install()
{
    nginx_configure_repo
    pkg_meta_update

    pkg_install nginx
    st2_install_pkg_version st2web ${ST2WEB_PKG_VERSION}

    sudo mkdir -p /etc/ssl/st2
    sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
    -days 365 -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information \
    Technology/CN=$(hostname)"

    sudo rm -f /etc/nginx/conf.d/default.conf

        sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        sudo awk '/^    server {/{f=1}f{$0 = "#" $0}{print}' /etc/nginx/nginx.conf.bak >/etc/nginx/nginx.conf
        sudo sed -i -e 's/##/#/' /etc/nginx/nginx.conf
        sudo sed -i -e 's/#}/}/' /etc/nginx/nginx.conf
    

    sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/conf.d/

    sudo systemctl enable nginx
    sudo systemctl restart nginx
}
mongodb_configure_repo()
{
    repo_definition "mongodb-org-7.0" \
                    "https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/" \
                    "mongodb-org-7.0-key" \
                    "https://pgp.mongodb.com/server-7.0.asc"
}
mongodb_configuration()
{
    local MONGODB_USER="mongod"
    local DB_PATH="/var/lib/mongo"
    local LOG_PATH="/var/log/mongodb"
    mongodb_write_configuration "$MONGODB_USER" "$DB_PATH" "$LOG_PATH"
    mongodb_adjust_selinux_policies
}


mongodb_write_configuration()
{
    local MONGODB_USER="$1"
    local DB_PATH="$2"
    local LOG_PATH="$3"
    local CFGFILE="/etc/mongod.conf"

    TMP=$(cat <<EOF
net:
  bindIp: 127.0.0.1
  port: 27017
storage:
  dbPath: $DB_PATH
systemLog:
  path: $LOG_PATH/mongod.log
  destination: file
  logAppend: true
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
security:
  authorization: disabled
EOF
)
    sudo bash -c "cat <<<\"$TMP\" >${CFGFILE}"
}

mongodb_adjust_selinux_policies()
{
    if getenforce | grep -q 'Enforcing'; then
        echo.info "Applying MongoDB SELinux policy."
        pkg_install git make checkpolicy policycoreutils selinux-policy-devel
        test -d /root/mongodb-selinux || sudo git clone https://github.com/mongodb/mongodb-selinux /root/mongodb-selinux
        cd /root/mongodb-selinux && \
        make && \
        sudo make install
    fi
}

mongodb_install()
{
    local MONGODB_PKG=mongodb-org

    if [[ $INSTALL_MONGODB -eq 0 ]]; then
        echo.info "Skip MongoDB: Installation explicitly disabled at runtime."
        return
    elif pkg_is_installed "$MONGODB_PKG"; then
        echo.info "Skip MongoDB: Package is already present on the system."
        return
    fi

    mongodb_configure_repo
    pkg_meta_update
    pkg_install "$MONGODB_PKG"
    mongodb_configuration

    sudo systemctl enable mongod
    sudo systemctl start mongod

    sleep 10

    mongosh <<EOF
use admin;
db.createUser({
    user: "admin",
    pwd: "${ST2_MONGODB_PASSWORD}",
    roles: [
        { role: "userAdminAnyDatabase", db: "admin" }
    ]
});
EOF

    mongosh <<EOF
use st2;
db.createUser({
    user: "stackstorm",
    pwd: "${ST2_MONGODB_PASSWORD}",
    roles: [
        { role: "readWrite", db: "st2" }
    ]
});
EOF

    sudo sed -ri 's/^  authorization: disabled$/  authorization: enabled/g' /etc/mongod.conf

    sudo systemctl restart mongod
}
rabbitmq_adjust_selinux_policies()
{
    if getenforce | grep -q 'Enforcing'; then
        pkg_install policycoreutils-python-utils

        sudo semanage port --list | grep -q 25672 || sudo semanage port -a -t amqp_port_t -p tcp 25672

        sudo setsebool -P httpd_can_network_connect 1
    fi
}

rabbitmq_install()
{
    local RABBITMQ_PKG=rabbitmq-server

    if [[ $INSTALL_RABBITMQ -eq 0 ]]; then
        echo.info "Skip RabbitMQ: Installation explicitly disabled at runtime."
        return
    elif pkg_is_installed "$RABBITMQ_PKG"; then
        echo.info "Skip RabbitMQ: Package is already present on the system."
        return
    fi
    repo_definition "erlang" \
                    "https://yum1.rabbitmq.com/erlang/el/9/\$basearch" \
                    "erlang-key" \
                    "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key"
    repo_definition "rabbitmq-server" \
                    "https://yum2.rabbitmq.com/rabbitmq/el/9/\$basearch" \
                    "rabbitmq-server-key" \
                    "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc"
    repo_definition "rabbitmq-server-noarch" \
                    "https://yum2.rabbitmq.com/rabbitmq/el/9/noarch" \
                    "rabbitmq-server-key" \
                    "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc"

    rabbitmq_adjust_selinux_policies

    local PKGS=(
        erlang
        "$RABBITMQ_PKG"
    )


    pkg_meta_update
    pkg_install ${PKGS[@]}

    sudo sh -c 'echo "RABBITMQ_NODE_IP_ADDRESS=127.0.0.1" >> /etc/rabbitmq/rabbitmq-env.conf'

    sudo systemctl enable rabbitmq-server
    sudo systemctl restart rabbitmq-server

    if ! sudo rabbitmqctl list_users | grep -E '^stackstorm'; then
        sudo rabbitmqctl add_user stackstorm "${ST2_RABBITMQ_PASSWORD}"
        sudo rabbitmqctl set_user_tags stackstorm administrator
        sudo rabbitmqctl set_permissions -p / stackstorm ".*" ".*" ".*"
    fi
    if sudo rabbitmqctl list_users | grep -E '^guest'; then
        sudo rabbitmqctl delete_user guest
    fi
}
redis_install()
{
    local REDIS_PKG=redis

    if [[ $INSTALL_REDIS -eq 0 ]]; then
        echo.info "Skip Redis: Installation explicitly disabled at runtime."
        return
    elif pkg_is_installed "$REDIS_PKG"; then
        echo.info "Skip Redis: Package is already present on the system."
        return
    fi
    local REDIS_SERVICE=redis

    pkg_meta_update
    pkg_install "$REDIS_PKG"

    TMP=$(cat <<EOF
bind 127.0.0.1
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
logfile /var/log/redis/redis.log
databases 16
dbfilename dump.rdb
dir /var/lib/redis
EOF
)
    if [[ -f /etc/redis.conf ]]; then
        sudo bash -c "cat <<<\"$TMP\" >/etc/redis.conf"
    elif [[ -f /etc/redis/redis.conf ]]; then
        sudo bash -c "cat <<<\"$TMP\" >/etc/redis/redis.conf"
    else
        echo.warning "Unable to find redis configuration file at /etc/redis.conf or /etc/redis/redis.conf."
    fi

    sudo systemctl enable "${REDIS_SERVICE}"
    sudo systemctl start "${REDIS_SERVICE}"
}

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
        --user=*|--username=*)
            USERNAME="${i#*=}"
            shift
            ;;
        --password=*)
            PASSWORD="${i#*=}"
            shift
            ;;
        --no-mongodb)
            INSTALL_MONGODB=0
            shift
            ;;
        --no-rabbitmq)
            INSTALL_RABBITMQ=0
            shift
            ;;
        --no-redis)
            INSTALL_REDIS=0
            shift
            ;;
        --no-st2chatops)
            INSTALL_ST2CHATOPS=0
            shift
            ;;
        --no-st2web)
            INSTALL_ST2WEB=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown parameter $i."
            usage
            exit 1
            ;;
    esac
done

trap 'fail' EXIT

step "Setup runtime arguments"
setup_install_parameters "$VERSION" "$RELEASE" "$REPO_TYPE" "$DEV_BUILD"
setup_username_password

step "Install required runtime packages"
system_install_runtime_packages

step "Check storage capacity and network ports"
system_check_resources

step "Configure HTTP Proxy"
system_configure_proxy

ST2_RABBITMQ_PASSWORD=$(system_generate_password 24)
ST2_MONGODB_PASSWORD=$(system_generate_password 24)
write_passwords

step "Install event bus (RabbitMQ)"
rabbitmq_install "$ST2_RABBITMQ_PASSWORD"

step "Install database (MongoDB)"
mongodb_install "$ST2_MONGODB_PASSWORD"

step "Install key/value store (Redis)"
redis_install

step "Install st2 (StackStorm)"
st2_install

step "Configure st2 system user account"
st2_configure_user

step "Configure st2 authentication"
st2_configure_authentication

step "Create st2 CLI configuration"
st2_configure_cli_config "$USERNAME" "$PASSWORD"

step "Setup datastore symmetric encryption"
st2_setup_kvstore_encryption_keys

step "Verify StackStorm installation"
st2_verification

step "Install Web Interface (st2web)"
st2web_install

step "Install ChatOps bot (st2chatops)"
st2chatops_install

step "Configure st2chatops"
st2chatops_configure

trap - EXIT

ok_message
