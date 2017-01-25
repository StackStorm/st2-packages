# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

VIRTUAL_MACHINES = {
  :trusty => {
    :hostname => 'st2-packages-trusty',
    :box => 'ubuntu/trusty64',
    :ip => '192.168.16.20',
  },
  :xenial => {
    :hostname => 'st2-packages-xenial',
    :box => 'ubuntu/xenial64',
    :ip => '192.168.16.21',
  },
  :el7 => {
    :hostname => 'st2-packages-el7',
    :box => 'centos/7',
    :ip => '192.168.16.22',
  },
}

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  VIRTUAL_MACHINES.each do |name, cfg|
    config.vm.define name do |vm_config|
      vm_config.vm.hostname = cfg[:hostname]
      vm_config.vm.box = cfg[:box]

      # Give VM access to all CPU cores on the host
      # docker-compose & rake build can benefit from more CPUs
      host_os = RbConfig::CONFIG['host_os']
      if host_os =~ /darwin/
        cpus = `sysctl -n hw.ncpu`.to_i
      elsif host_os =~ /linux/
        cpus = `nproc`.to_i
      else # sorry Windows folks, I can't help you
        cpus = 2
      end

      # Box Specifications
      vm_config.vm.provider :virtualbox do |vb|
        vb.name = "#{cfg[:hostname]}"
        # NOTE: With 2048MB, system slows due to kswapd. Recommend at least 4096MB.
        vb.customize ['modifyvm', :id, '--memory', '4096']
        vb.customize ["modifyvm", :id, "--cpus", cpus]
      end

      # Sync folder using NFS
      vm_config.vm.synced_folder '.', '/vagrant', nfs: true

      # Configure a private network
      vm_config.vm.network "private_network", ip: "#{cfg[:ip]}"

      # Public (bridged) network may come handy for external access to VM (e.g. sensor development)
      # See https://www.vagrantup.com/docs/networking/public_network.html
      # st2.vm.network "public_network", bridge: 'en0: Wi-Fi (AirPort)'

      # Install docker-engine
      vm_config.vm.provision :docker

      vm_config.vm.provision 'shell', path: 'scripts/setup-vagrant.sh', privileged: false, env: {
        "ST2_TARGET" => "#{name}",
        "ST2_USER" => ENV['ST2USER'] ? ENV['ST2USER'] : 'st2admin',
        "ST2_PASSWORD" => ENV['ST2PASSWORD'] ? ENV['ST2PASSWORD'] : 'st2admin',
        "ST2_INSTALL" => ENV['ST2_INSTALL'] ? ENV['ST2_INSTALL'] : 'yes',
        "ST2_VERIFY" => ENV['ST2_VERIFY'] ? ENV['ST2_VERIFY'] : 'yes',
        "ST2_GITURL" => ENV['ST2_GITURL'],
        "ST2_GITREV" => ENV['ST2_GITREV'],
        "ST2MISTRAL_GITURL" => ENV['ST2MISTRAL_GITURL'],
        "ST2MISTRAL_GITREV" => ENV['ST2MISTRAL_GITREV'],
      }
    end
  end
end
