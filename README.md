% Create a Test Environment with vagrant
% Progedo stage (2ndQuadrant Italia)
% 07 March 2018
---
fontsize: 10pt
fontfamily: fouriernc
classoption: oneside
copyright-holder: 2ndQuadrant Italia S.r.l.
version: 1
customer: PROGEDO
copyright-years: 2018
lange: en
---

# Introduction

Welcome to the documentation for our Linux Test Environment.
If you want a fast and easy way to create your virtualized test environment just follow the guide down below.
We added a provisioning script that configures a Barman-Master instance.  


# Minimum Requirements

Host Operating System: Linux (tested on Ubuntu 16.04)
Vagrant version: 2.0.2
Virtualbox version: 5.1

# VirtualBox and Vagrant installation

To install the latest release of VirtualBox and Vagrant follow the official documentation at:

   1. [Download Virtualbox](https://www.virtualbox.org/wiki/Linux_Downloads)
   2. [Download Vagrant](https://releases.hashicorp.com/vagrant/)

# Configure your vagrantfile

**You can leave anything as deafault** or edit your Vagrantfile to customize even more your Test Environment.

You might be interested into editing your Vagrantfile if you want to:

   1. Increase the number of Virtual Machines
   2. Manage your virtual machines ip and hostname
   3. Choose other boxes (Linux Distributions) for your VMs:
   (You can look for vagrant boxes here [Download Boxes](https://app.vagrantup.com/boxes/search) )
   *We recommend you to use only official boxes that comes from trusted sources*

# Configure SSH keys

We have already setup an ssh key for this test environment, but if you want to change it, just delete them from this folder and create the new one (`ssh-keygen -f ./id_rsa -N ''`).
The keys must be named as **id_rsa** and **id_rsa.pub** and they must be in the same directory of the Vagrantfile. If you want to use your personal keys instead then you have to edit the 'Vagrantfile' with the exact path to your keys ( change "files/id_rsa" and "files/id_rsa.pub" to "YOUR_PATH/id_rsa" and "YOUR_PATH/id_rsa.pub" ).

# Get your Virtual Machines ready

To boot up your machines just run the following from your terminal: (make sure to be in the same folder of your Vagrantfile)

   * `vagrant up`
Note: If you use libvirt( kvm ) instead of VirtualBox as a provider, use 'vagrant up --no-parallel'

Now that your machines are running there are multiple ways to access them:

   1. `vagrant ssh HOSTNAME`
   2. `ssh vagrant@MACHINE_IP -i id_rsa` (rsa key exchange required -> ssh-add id_rsa)
   3. `ssh root@MACHINE_IP -i id_rsa (Root Access)` (rsa key exchange required -> ssh-add id_rsa)

# Custom connection options

If you want to access your machines just by typing

   * `ssh HOSTNAME`

do the following:

   1. Move into your Vagrantfile directory
   2. `vagrant ssh-config >> ~/.ssh/config`

Since you don't specify the host user anymore, it's going to access with the default user (vagrant).
If you want root access as default:

   1. Edit ~/.ssh/config
   2. Change the parameter *'User'* for every machine from "vagrant" to "root"

# Provisioning for Master-Standby-Barman
Barman and Postgresql are configured with the files "pg10-MSB-provision.sh" and "progedo-server.conf".
The Vagrantfile that we provide is already configured to use as-is.
Note: The "pg10-msb-provision.sh" (with lower 'msb') is the file with all the commands, one after another, it can help you to understand every step that has to be taken but is not very manageable.

# Provisioning for barman and postgres only
Barman and Postgres are configured with the files "pg10-barman-provision.sh", "ssh-server.conf" , "streaming-server.conf" and "progedo-server.conf".
By default the only active file is progedo-server.conf wich provides an hybrid connection to our master.
If you want this architecture, you have to comment the creation of the pg02 VM and change the name of the provisioning script in the provided Vagrantfile.

# Provisioning for postgres only
Postgres is configured with the file "pg10-provision.sh".
If you want this architecture you have to comment the creation of the barman VM, the pg02 VM and change the name of the provisioning script in the provided Vagrantfile.
