#VAGRANTFILE
# -*- mode: ruby -*-
# vi: set ft=ruby :

#Calling the ruby shell to execute bash commands and saving exit_code(true/false) on a variable
exit_code = system("
	#PWD PATH
	VFILE_PATH=$PWD
	#Vagrantfile expected path(Not The Real Vagrantfile Path)
	VFILE_PATH=$VFILE_PATH'/Vagrantfile'
	#Check if the user is calling vagrant up
	if [ '#{ARGV[0]}' = 'up' ]; then
		#Check if the user is inside the Vagrantfile directory
    		if [ ! -e $VFILE_PATH ]; then
			#Exit with False state code
    			echo '\033[0;31mVagrantfile not found! Move in the same directory of your Vagrantfile.'
			exit 1
    		else
			#Exit with True state code
			echo '\033[0;31mScript Initialized!'
			exit 0
		fi
	fi
	#Not launching vagrant up
	exit 0
")

#Check on the exit_code.This runs or terminate the whole Vagrantfile script.
if exit_code == false
	exit
end

#All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|

  config.ssh.insert_key = false
  #config.vm.synced_folder ".", "/vagrant", disabled: true

  #Configure path for local private key
  config.ssh.private_key_path = ["files/id_rsa",
                                 "~/.vagrant.d/insecure_private_key"]

  #Configure id_rsa.pub into the auth_key for every VM
  config.vm.provision "file",
                      run: 'once',
                      source: "files/id_rsa.pub",
                      destination: "~/.ssh/authorized_keys"

  #script
  config.vm.provision "shell", path: "script.d/pg10-MSB-provision.sh"

  #Configure hostname, ip address and OS here:
  nodes =  [
  {
		:hostname => 'barman',
		:ip => '192.168.42.100',
		:box => 'ubuntu/xenial64'
  },
  {
		:hostname => 'pg01',
		:ip => '192.168.42.101',
		:box => 'ubuntu/xenial64'
  },
  {
		:hostname => 'pg02',
		:ip => '192.168.42.102',
		:box => 'ubuntu/xenial64'
  },
	  ]

  nodes.each do |node|
    config.vm.define node[:hostname] do |host|
      host.vm.box = node[:box]
      host.vm.hostname = node[:hostname]
      host.vm.network :private_network, ip: node[:ip]
    end
  end
end
