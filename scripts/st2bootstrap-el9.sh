#!/usr/bin/env bash
# Copyright 2025 The StackStorm Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# DO NOT EDIT MANUALLY.  GENERATED FOR rocky 9
#
# Please edit the corresponding template file and include files in https://github.com/StackStorm/st2-packages.git.

set -e -u +x

# ============================ Global variables ============================
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

# Prefix operating system variables with OS_ to avoid conflicts in the script.
# References: https://github.com/chef/os_release
source <(sed 's/^/OS_/g' /etc/os-release)

# ============================ Function declarations ============================
###############[ SCRIPT HELP ]###############
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
# colour echo (ref https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences)
function cecho()
{
    if [[ "$1" == "-n" ]]; then
        # No carrage return
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
###############[ SCRIPT PARAMETER SETUP ]###############
setup_install_parameters()
{
    # Valid release repository combinations:
    #   stable with version x.y.z
    #       https://packagecloud.io/StackStorm/stable           (st2web-3.8.1-1.x86_64.rpm)
    #   staging-stable with version x.y.z
    #       https://packagecloud.io/StackStorm/staging-stable   (st2chatops_3.8.1-1_amd64.deb)
    #   unstable with version x.ydev
    #       https://packagecloud.io/StackStorm/unstable         (st2-3.9dev-208.x86_64.rpm)
    #   staging-unstable with version x.ydev
    #       https://packagecloud.io/StackStorm/staging-unstable (st2-3.9dev-97.x86_64.rpm)
    local VERSION="$1"
    local RELEASE="$2"
    local REPO_TYPE="$3"
    local DEV_BUILD="$4"

    # Set the installation type to use in the script.
    if [[ -n "$DEV_BUILD" ]]; then
        # Development builds use the package produced from CI directly.
        # https://output.circle-artifacts.com/output/job/e404c552-f8d6-46bd-9034-0267148874db/artifacts/0/packages/focal/st2_3.9dev-186_amd64.deb
        # CircleCI pipeline repo: st2, branch: master, workflow: package-test-and-deploy, job: 17505
        INSTALL_TYPE["CI"]="$DEV_BUILD"
        if [[ ! "$DEV_BUILD" =~ [^/]+/[0-9]+ ]]; then
            echo.error "Unexpected format '$DEV_BUILD'.  Format must be 'repo_name/build_id'"
            exit 1
        fi
        echo.warning "Installation of $DEV_BUILD from CI build artifacts!  REALLY, ANYTHING COULD HAPPEN!"
    else
        # non-development builds use the PackageCloud repositories.
        setup_select_repository "$VERSION" "$RELEASE" "$REPO_TYPE"
    fi
}


setup_check_version()
{
    # StackStorm version sanity check.  Report and error and exit if
    # the version doesn't conform to the format x.y.z or x.ydev
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

    # Version takes precedence over requested release
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
###############[ PACKAGE MANAGER FUNCTIONS ]###############
pkg_install()
{
    
    sudo dnf -y install $@
}

pkg_meta_update()
{
    # Update the package metadata to the latest information from the repostories.
    
    sudo dnf -y check-update
    # to do: which is more appropriate.
    #sudo dnf makecache --refresh
    
}

pkg_is_installed()
{
    PKG="$1"
    # Check for package installed on system
    
    sudo rpm -q "$PKG" | grep -qE "^${PKG}"
    
}
###############[ REPOSITORY MANAGER FUNCTIONS ]###############


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
    # Approximately equivalanet to apt-cache show
    dnf -y info --showduplicates "$1"
    # output processing hint (not completely correct):
    # dnf info --showduplicates st2 | sed -r 's/ +: +/:/g' | awk -F: '/^(Name|Version|Release|Architecture|Size|Source|Repository|Summary|URL|License|Description)/ {print $2} | xargs -n11 | column -t
}


repo_clean_meta()
{
    dnf -y clean metadata
    dnf -y clean dbcache
    dnf -y clean all
}


repo_pkg_availability() {
    # repo_pkg_availability  <PKG> <VERSION>
    local PKG="$1"
    local VERSION="$2"

    local PKG_VER=""
    
        # rpm based systems.
        PKG_VER=$(pkg_get_latest_version "$PKG" "${VERSION}")
    

    if [[ -z "$PKG_VER" ]]; then
        echo.error "${PKG}-${VERSION} couldn't be found in the pacakges available on this system."
        exit 3
    fi
    echo "$PKG_VER"
}
###############[ COMMON FUNCTIONS ]###############
system_install_runtime_packages()
{
    
    # Extra Packages for Enterprise Linux (EPEL) for crudini requirement
    if ! pkg_is_installed epel-release; then
        pkg_install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    fi
    
    local PKG_DEPS=(
        crudini
        curl
        jq
        logrotate
        net-tools
        # Use repoquery tool from yum-utils to get package_name-package_ver-package_rev in RPM based distros
        # if we don't want to construct this string manually using yum info --show-duplicates and
        # doing a bunch of sed awk magic. Problem is this is not installed by default on all images.
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
    # Allow bypassing 'proxy' env vars via sudo
    local sudoers_proxy='Defaults env_keep += "http_proxy https_proxy no_proxy proxy_ca_bundle_path DEBIAN_FRONTEND"'
    if ! sudo grep -s -q ^"${sudoers_proxy}" /etc/sudoers.d/st2; then
        sudo sh -c "echo '${sudoers_proxy}' >> /etc/sudoers.d/st2"
    fi

    # Configure proxy env vars for 'st2api', 'st2actionrunner' and 'st2chatops' system configs
    # See: https://docs.stackstorm.com/packs.html#installing-packs-from-behind-a-proxy
    service_config_path=""
    # sysconfig and default exist on RedHat systems, so sysconfig must be first in the search list.
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
        # create file if doesn't exist yet
        sudo test -e "${service_config}" || sudo touch "${service_config}"
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


system_port_status()
{
    # If the specified tcp4 port is bound, then return the "port pid/procname",
    # else if a pipe command fails, return "Unbound",
    # else return "".
    #
    # Please note that all return values end with a newline.
    #
    # Use netstat and awk to get a list of all the tcp4 sockets that are in the LISTEN state,
    # matching the specified port.
    #
    # `ss` command is expected to output data in the below format:
    #    Netid State  Recv-Q Send-Q  Local Address:Port   Peer Address:Port Process
    #    tcp   LISTEN 0      511           0.0.0.0:80          0.0.0.0:*     users:(("nginx",pid=421,fd=6),("nginx",pid=420,fd=6))

    # The awk command prints the 4th and 7th columns of any line matching both the following criteria:
    #   1) The 5th column contains the port passed to port_status()  (i.e., $1)
    #   2) The 7th column contains the process bound (listening) to the port.
    #
    # Sample output:
    #   0.0.0.0:80 users:(("nginx",pid=421,fd=6),("nginx",pid=420,fd=6))
    sudo ss -ltpun4 "sport = :$1" | awk '/tcp.*LISTEN.*/ {print $5" "$7}' || echo "Unbound"
}


system_check_resources()
{
    # CHECK 1: Determine which, if any, of the required ports are used by an existing process.

    # Abort the installation early if the following ports are being used by an existing process.
    # nginx (80, 443), mongodb (27017), rabbitmq (4369, 5672, 25672), redis (6379)
    # and st2 (9100-9102).
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

    # If any used ports were found, display helpful message and exit 
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

    # CHECK 2: Ensure there is enough space at /var/lib/mongodb
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
###############[ STACKSTORM ]###############

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
    # Use jinja version id for major version only.
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
    # Retrieve package URL for the provided dev build from CircleCI build pipeline.
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

    # Configure [database] section in st2.conf (username password for MongoDB access)
    local DB_URI="mongodb://stackstorm:${ST2_MONGODB_PASSWORD}@127.0.0.1:27017/st2?authSource=st2"
    sudo crudini --set "$ST2_CFGFILE" database host "$DB_URI"

    # Configure [messaging] section in st2.conf (username password for RabbitMQ access)
    local AMQP="amqp://stackstorm:$ST2_RABBITMQ_PASSWORD@127.0.0.1:5672"
    sudo crudini --set "$ST2_CFGFILE" messaging url "${AMQP}"

    # Configure [coordination] section in st2.conf (url for Redis access)
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

    # Create a user record in a password file.
    sudo htpasswd -i /etc/st2/htpasswd $USERNAME <<<"${PASSWORD}"

    # Configure [auth] section in st2.conf
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


st2_configure_cli_config()
{
    local USERNAME="$1"
    local PASSWORD="$2"
    test -z "$USERNAME" && ( echo.error "Can't configure cli, missing username."; exit 9 )
    test -z "$PASSWORD" && ( echo.error "Can't configure cli, missing password."; exit 9 )

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

    # Write config for root user
    sudo sh -c "cat <<EOF >${ROOT_USER_CLI_CONFIG_PATH}
[credentials]
username = ${USERNAME}
password = ${PASSWORD}
EOF"

    # Write config for current user (in case current user is not the root user)
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

    # Fix the permissions
    sudo chown -R ${CURRENT_USER}:${CURRENT_USER} ${CURRENT_USER_CLI_CONFIG_DIRECTORY}
}


st2_setup_kvstore_encryption_keys()
{
    DATASTORE_ENCRYPTION_KEYS_DIRECTORY="/etc/st2/keys"
    DATASTORE_ENCRYPTION_KEY_PATH="${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}/datastore_key.json"

    sudo mkdir -p ${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}

    # If the file ${DATASTORE_ENCRYPTION_KEY_PATH} exists and is not empty, then do not generate
    # a new key. st2-generate-symmetric-crypto-key fails if the key file already exists.
    if ! sudo test -s ${DATASTORE_ENCRYPTION_KEY_PATH}; then
        sudo st2-generate-symmetric-crypto-key --key-path ${DATASTORE_ENCRYPTION_KEY_PATH}
    fi

    # Make sure only st2 user can read the file
    for dir in "${DATASTORE_ENCRYPTION_KEYS_DIRECTORY}" "${DATASTORE_ENCRYPTION_KEY_PATH}"
    do
        sudo chgrp st2 "$dir"
        sudo chmod o-r "${dir}"
    done
    # set path to the key file in the config
    sudo crudini --set /etc/st2/st2.conf keyvalue encryption_key_path ${DATASTORE_ENCRYPTION_KEY_PATH}

    # NOTE: We need to restart all the affected services so they pick the key and load it in memory
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
    # A shortcut to authenticate and export the token
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
###############[ ST2CHATOPS ]###############
nodejs_configure_repository()
{
    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo -E bash -
}

st2chatops_install()
{
    # Add NodeJS 20 repo
    nodejs_configure_repository
    pkg_install nodejs

    # Install st2chatops
    st2_install_pkg_version st2chatops ${ST2CHATOPS_PKG_VERSION}
}

st2chatops_configure()
{
    # set API keys. This should work since CLI is configuered already.
    ST2_API_KEY=$(st2 apikey create -k)
    sudo sed -i -r "s/^(export ST2_API_KEY.).*/\1$ST2_API_KEY/" /opt/stackstorm/chatops/st2chatops.env

    sudo sed -i -r "s/^(export ST2_AUTH_URL.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export ST2_AUTH_USERNAME.).*/# &/" /opt/stackstorm/chatops/st2chatops.env
    sudo sed -i -r "s/^(export ST2_AUTH_PASSWORD.).*/# &/" /opt/stackstorm/chatops/st2chatops.env

    # Setup adapter
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
###############[ ST2WEB ]###############
nginx_configure_repo()
{
    repo_definition "nginx" \
                    "http://nginx.org/packages/rhel/9/x86_64/" \
                    "nginx-key" \
                    "http://nginx.org/keys/nginx_signing.key"

    # Ensure that EPEL repo is not used for nginx (to do: confirm this is still needed)
    #~ sudo sed -i 's/^\(enabled=1\)$/exclude=nginx\n\1/g' /etc/yum.repos.d/epel.repo
}

st2web_install()
{
    nginx_configure_repo
    pkg_meta_update

    pkg_install nginx
    st2_install_pkg_version st2web ${ST2WEB_PKG_VERSION}

    # Generate self-signed certificate or place your existing certificate under /etc/ssl/st2
    sudo mkdir -p /etc/ssl/st2
    sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
    -days 365 -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information \
    Technology/CN=$(hostname)"

    # Remove default site, if present
    sudo rm -f /etc/nginx/conf.d/default.conf

    # back up conf
        sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        # comment out server block eg. server {...}
        sudo awk '/^    server {/{f=1}f{$0 = "#" $0}{print}' /etc/nginx/nginx.conf.bak >/etc/nginx/nginx.conf
        # remove double comments
        sudo sed -i -e 's/##/#/' /etc/nginx/nginx.conf
        # remove comment closing out server block
        sudo sed -i -e 's/#}/}/' /etc/nginx/nginx.conf
    

    # Copy and enable StackStorm's supplied config file
    sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/conf.d/

    sudo systemctl enable nginx
    sudo systemctl restart nginx
}
###############[ MONGODB ]###############
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
        # RHEL9 selinux policy is more restrictive than RHEL8 by default which requires
        # the installation of a mongodb policy to allow it to run.
        # Note that depending on distro assembly/settings you may need more rules to change
        # Apply these changes OR disable selinux in /etc/selinux/config (manually)
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

    # Require authentication to be able to acccess the database
    sudo sed -ri 's/^  authorization: disabled$/  authorization: enabled/g' /etc/mongod.conf

    # MongoDB needs to be restarted after enabling auth
    sudo systemctl restart mongod
}
###############[ RABBITMQ ]###############
rabbitmq_adjust_selinux_policies()
{
    if getenforce | grep -q 'Enforcing'; then
        # SELINUX management tools, not available for some minimal installations
        pkg_install policycoreutils-python-utils

        # Allow rabbitmq to use '25672' port, otherwise it will fail to start
        sudo semanage port --list | grep -q 25672 || sudo semanage port -a -t amqp_port_t -p tcp 25672

        # Allow network access for nginx
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
# https://www.rabbitmq.com/docs/install-rpm
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

    # Configure RabbitMQ to listen on localhost only
    sudo sh -c 'echo "RABBITMQ_NODE_IP_ADDRESS=127.0.0.1" >> /etc/rabbitmq/rabbitmq-env.conf'

    sudo systemctl enable rabbitmq-server
    sudo systemctl restart rabbitmq-server

    # configure RabbitMQ
    if ! sudo rabbitmqctl list_users | grep -E '^stackstorm'; then
        sudo rabbitmqctl add_user stackstorm "${ST2_RABBITMQ_PASSWORD}"
        sudo rabbitmqctl set_user_tags stackstorm administrator
        sudo rabbitmqctl set_permissions -p / stackstorm ".*" ".*" ".*"
    fi
    if sudo rabbitmqctl list_users | grep -E '^guest'; then
        sudo rabbitmqctl delete_user guest
    fi
}
###############[ REDIS ]###############
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
# https://redis.io/docs/latest/operate/oss_and_stack/install/archive/install-redis/install-redis-on-linux/#install-on-red-hatrocky
    # use system provided packages.
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
        # redis v5 configuration
        sudo bash -c "cat <<<\"$TMP\" >/etc/redis.conf"
    elif [[ -f /etc/redis/redis.conf ]]; then
        # redis v6 configuration
        sudo bash -c "cat <<<\"$TMP\" >/etc/redis/redis.conf"
    else
        echo.warning "Unable to find redis configuration file at /etc/redis.conf or /etc/redis/redis.conf."
    fi

    sudo systemctl enable "${REDIS_SERVICE}"
    sudo systemctl start "${REDIS_SERVICE}"
}

# ============================ Main script logic ============================
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
# Side-effect: INSTALL_TYPE is updated from setup_install_parameters()
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