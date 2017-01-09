# -*- mode: ruby -*-
# vi: set ft=ruby :

hostname      = 'st2-packages'
st2user       = ENV['ST2USER'] ? ENV['ST2USER']: 'st2admin'
st2passwd     = ENV['ST2PASSWORD'] ? ENV['ST2PASSWORD'] : 'Ch@ngeMe'
box           = ENV['BOX'] ? ENV['BOX'] : 'centos/7'

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

VIRTUAL_MACHINES = {
  :ubuntu14 => {
    :hostname => 'ubuntu14',
    :box => 'ubuntu/trusty64',
    :target => 'trusty',
  },
  :ubuntu16 => {
    :hostname => 'ubuntu16',
    :box => 'ubuntu/xenial64',
    :target => 'xenial',
  },
  :centos6 => {
    :hostname => 'centos6',
    :box => 'centos/6',
    :target => 'el6',
  },
  :centos7 => {
    :hostname => 'centos7',
    :box => 'centos/7',
    :target => 'el7',
  },
}

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  VIRTUAL_MACHINES.each do |name, cfg|
    config.vm.define name do |vm_config|
      vm_config.vm.hostname = cfg[:hostname]
      vm_config.vm.box = cfg[:box]

      # Box Specifications
      vm_config.vm.provider :virtualbox do |vb|
        vb.name = "#{cfg[:hostname]}"
        vb.customize ['modifyvm', :id, '--memory', '2048']
        vb.cpus = 2
      end

      # Sync folder using NFS
      vm_config.vm.synced_folder '.', '/vagrant', nfs: true

      # Configure a private network
      vm_config.vm.network "private_network", ip: '192.168.16.20'

      # Public (bridged) network may come handy for external access to VM (e.g. sensor development)
      # See https://www.vagrantup.com/docs/networking/public_network.html
      # st2.vm.network "public_network", bridge: 'en0: Wi-Fi (AirPort)'
      # Install docker-engine and docker-compose
      vm_config.vm.provision :docker

      if vm_config.vm.hostname.include? "ubuntu"
        vm_config.vm.provision :shell, :path => "scripts/setup-ubuntu.sh", :privileged => false, :args => cfg[:target]
      end
      if vm_config.vm.hostname.include? "centos"
        vm_config.vm.provision :shell, :path => "scripts/setup-centos.sh", :privileged => false, :args => cfg[:target]
      end
    end
  end
end
