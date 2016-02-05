#!/bin/bash

install_dependencies() {
	sudo apt-get update
	sudo apt-get install -y mongodb-server rabbitmq-server postgresql
}

setup_repositories() {
	wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
	echo "deb https://dl.bintray.com/stackstorm/trusty_staging stable main" | sudo tee /etc/apt/sources.list.d/st2-stable.list
	sudo apt-get update
}

install_stackstorm_components() {
	sudo apt-get update
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
	sudo chmod 0700 /home/stanley/.ssh

	# Generate ssh keys on StackStorm box and copy over public key into remote box.
	sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""
	#sudo cp ${KEY_LOCATION}/stanley_rsa.pub /home/stanley/.ssh/stanley_rsa.pub

	# Authorize key-base acces
	sudo cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys
	sudo chmod 0600 /home/stanley/.ssh/authorized_keys
	sudo chown -R stanley:stanley /home/stanley

	# Enable passwordless sudo
	sudo echo "stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2

	##### NOTE STILL NEED ADJUST CONFIGURATION FOR ST2 USER SECTION #####
}

use_st2ctl() {
	sudo st2ctl $1
}

configure_authentication() {
	# Install htpasswd utility if you don't have it
	sudo apt-get install -y apache2-utils
	# Create a user record in a password file.
	echo "Ch@ngeMe" | sudo htpasswd -i /etc/st2/htpasswd test

	# Get an auth token and use in CLI or API
	st2 auth test || echo "Failed on st2 auth test"

	# A shortcut to authenticate and export the token
	export ST2_AUTH_TOKEN=$(st2 auth test -p Ch@ngeMe -t)

	# Check that it works
	st2 action list  || echo "Failed on st2 action list in Configure Authentication"
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
    echo "First time starting this machine up?"
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

	st2 --version || (echo "Failed on st2 --version"; exit 2)
	st2 -h || (echo "Failed on st2 -h"; exit 2)
	st2 action list --pack=core || (echo "Failed on st2 action list"; exit 2)
	st2 run core.local -- date -R || (echo "Failed on st2 run core.local -- date -R"; exit 2)
	st2 execution list || (echo "Failed on st2 execution list"; exit 2)
	st2 run core.remote hosts="127.0.0.1" -- uname -a || (echo "Failed on st2 run core.remote hosts="localhost" -- uname -a"; exit 2)
	st2 run packs.install packs=st2 || (echo "Failed on st2 run packs.install packs=st2"; exit 2)
    ok_message

}


## Let's do this!

install_dependencies || (echo "Failed on install_dependencies"; exit 2)
setup_repositories || (echo "Failed on setup_repositories"; exit 2)
install_stackstorm_components || (echo "Failed on install_stackstorm_components"; exit 2)
setup_mistral_database || (echo "Failed on setup_mistral_database"; exit 2)
configure_authentication || (echo "Failed on configure_authentication"; exit 2)
use_st2ctl start || (echo "Failed on use_st2ctl start"; exit 2)
use_st2ctl reload || (echo "Failed on use_st2ctl reload"; exit 2)
verify
