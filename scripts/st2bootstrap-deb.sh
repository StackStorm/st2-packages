#!/bin/bash

fail() {
	echo "############### ERROR ###############"
	echo "# Failed on $1 #"
	echo "#####################################"
	exit 2
}

install_dependencies() {
	sudo apt-get update
	sudo apt-get install -y curl mongodb-server rabbitmq-server postgresql
}

setup_repositories() {
    # Following script adds a repo file, registers gpg key and runs apt-get update
    curl -s https://packagecloud.io/install/repositories/StackStorm/staging-stable/script.deb.sh | sudo bash
}

install_stackstorm_components() {
	sudo apt-get install -y st2 st2mistral
}

setup_mistral_database() {
	cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD

	# Setup Mistral DB tables, etc.
	/opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
	# Register mistral actions
	/opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate
}

configure_ssh_and_sudo () {

	# Create an SSH system user
	sudo useradd stanley
	sudo mkdir -p /home/stanley/.ssh

	# Generate ssh keys on StackStorm box and copy over public key into remote box.
	sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""
	#sudo cp ${KEY_LOCATION}/stanley_rsa.pub /home/stanley/.ssh/stanley_rsa.pub

	# Authorize key-base acces
	sudo cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys
	sudo chmod 0600 /home/stanley/.ssh/authorized_keys
	sudo chmod 0700 /home/stanley/.ssh
	sudo chown -R stanley:stanley /home/stanley

	# Enable passwordless sudo
	sudo echo "stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2

	##### NOTE STILL NEED ADJUST CONFIGURATION FOR ST2 USER SECTION #####
}

use_st2ctl() {
	sudo st2ctl $1
}

configure_authentication() {
	sed -i '/^\[auth\]$/,/^\[/ s/^enable = False/enable = True/' /etc/st2/st2.conf
	# Install htpasswd utility if you don't have it
	sudo apt-get install -y apache2-utils
	# Create a user record in a password file.
	sudo echo "Ch@ngeMe" | sudo htpasswd -i /etc/st2/htpasswd test

}

install_webui_and_setup_ssl_termination() {
	# Install st2web and nginx
	sudo apt-get install -y st2web nginx

	# Generate self-signed certificate or place your existing certificate under /etc/ssl/st2
	sudo mkdir -p /etc/ssl/st2
	sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
	-days XXX -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information \
	Technology/CN=$(hostname)"

	# Remove default site, if present
	sudo rm /etc/nginx/sites-enabled/default
	# Copy and enable StackStorm's supplied config file
	sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/sites-available/
	sudo ln -s /etc/nginx/sites-available/st2.conf /etc/nginx/sites-enabled/st2.conf

	sudo service nginx restart
}

ok_message() {
    ST2_IP=`ifconfig | grep 'inet addr' | awk '{print $2 }' | awk 'BEGIN {FS=":"}; {print $2}' | head -n 1`

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
    echo "Head to https://${ST2_IP} to access the WebUI"
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

verify() {

	st2 auth test -p Ch@ngeMe || fail "st2 auth test"
	# A shortcut to authenticate and export the token
	export ST2_AUTH_TOKEN=$(st2 auth test -p Ch@ngeMe -t)

	st2 --version || fail "st2 --version"
	st2 -h || fail "st2 -h"
	st2 action list --pack=core || fail "st2 action list"
	st2 run core.local -- date -R || fail "st2 run core.local -- date -R"
	st2 execution list || fail "st2 execution list"
	st2 run core.remote hosts='127.0.0.1' -- uname -a || fail "st2 run core.remote hosts='127.0.0.1' -- uname -a"
	st2 run packs.install packs=st2 || fail "st2 run packs.install packs=st2"
    ok_message

}

## Let's do this!

install_dependencies || fail "install_dependencies"
setup_repositories || fail "setup_repositories"
install_stackstorm_components || fail "install_stackstorm_components"
setup_mistral_database || fail "setup_mistral_database"
configure_ssh_and_sudo || fail "configure_ss_and_sudo"
configure_authentication || fail "configure_authentication"
install_webui_and_setup_ssl_termination || fail "install_webui_and_setup_ssl_termination"
use_st2ctl start || fail "use_st2ctl start"
use_st2ctl reload || fail "use_st2ctl reload"
verify
