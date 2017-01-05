# -*- mode: ruby -*-
# vi: set ft=ruby :

release       = ENV['RELEASE'] ? ENV['RELEASE'] : 'stable'
hostname      = ENV['HOSTNAME'] ? ENV['HOSTNAME'] : 'st2vagrant'
private_ip    = ENV['PRIVATE_IP'] ? ENV['PRIVATE_IP'] : '192.168.16.20'
st2user       = ENV['ST2USER'] ? ENV['ST2USER']: 'st2admin'
st2passwd     = ENV['ST2PASSWORD'] ? ENV['ST2PASSWORD'] : 'Ch@ngeMe'
box           = ENV['BOX'] ? ENV['BOX'] : 'centos/7'
source_folder = ENV['SRC_FOLDER']   || nil
dest_folder   = ENV['DST_FOLDER']   || nil

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "st2" do |st2|
    # Box details
    st2.vm.box = "#{box}"
    st2.vm.hostname = "#{hostname}"

    # Box Specifications
    st2.vm.provider :virtualbox do |vb|
      vb.name = "#{hostname}"
      vb.memory = 2048
      vb.cpus = 2
    end

    # NFS-synced directory
    if !source_folder.nil? and !dest_folder.nil?
      st2.vm.synced_folder "#{source_folder}", "#{dest_folder}", :nfs => true, :mount_options => ['nfsvers=3']
    end

    # Configure a private network
    st2.vm.network "private_network", ip: "#{private_ip}"

    # Public (bridged) network may come handy for external access to VM (e.g. sensor development)
    # See https://www.vagrantup.com/docs/networking/public_network.html
    # st2.vm.network "public_network", bridge: 'en0: Wi-Fi (AirPort)'
    # Install docker-engine and docker-compose
    st2.vm.provision :docker
    st2.vm.provision :shell, :path => "scripts/setup.sh", :privileged => false
  end
end
