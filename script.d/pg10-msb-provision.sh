#!/bin/bash

# Create directory and set ssh to have root access
if [ ! -d "/root/.ssh" ];then
    sudo mkdir /root/.ssh
fi
sudo cp .ssh/authorized_keys /root/.ssh/

#ssh access between Virtual Machines
cat /vagrant/files/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
cp /vagrant/files/id_rsa /home/vagrant/.ssh/
sudo chown vagrant:vagrant /home/vagrant/.ssh/id_rsa

# Select through the hostname check the machine to install barman or postgresql
HOSTNAME=$(hostname)

if [ "$HOSTNAME" = "barman" ];then

    	# Add Postgresql@10 apt repository on Ubuntu
    	sudo add-apt-repository 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main'

    	# Import the repository signing key
   	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
          	sudo apt-key add -

    	# Update the package lists
    	sudo apt-get update

    	# Install barman
    	sudo apt-get install barman -y

    	# copy ssh-server.conf and streaming-server.conf in barman.d
    	cp /vagrant/files/progedo-server.conf /etc/barman.d/
    	cp /vagrant/files/ssh-server.conf /etc/barman.d/
    	cp /vagrant/files/streaming-server.conf /etc/barman.d/

    	# Create directory and set ssh for barman-postgres comunication in Ubuntu
    	mkdir /var/lib/barman/.ssh
    	cat /vagrant/files/id_rsa.pub >> /var/lib/barman/.ssh/authorized_keys
    	cp /vagrant/files/id_rsa /var/lib/barman/.ssh/
    	chown -R barman:barman /var/lib/barman/.ssh
	
	#create file .pgpass
	echo "*:*:*:barman:barman" >> /var/lib/barman/.pgpass
	echo "*:*:*:streaming_barman:streaming_barman" >> /var/lib/barman/.pgpass
	echo "*:*:*:repuser:repuser" >> /var/lib/barman/.pgpass

	chmod 600 /var/lib/barman/.pgpass
	chown barman:barman /var/lib/barman/.pgpass


elif [ "$HOSTNAME" = "pg01" ];then
	
    	# Add Postgresql@10 apt repository on Ubuntu	
    	sudo add-apt-repository 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main'

    	# Import the repository signing key
    	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
          sudo apt-key add -

    	# Update the package lists
    	sudo apt-get update

    	# Install Postgresql
    	sudo apt install postgresql-10 -y

    	# open listen_addresses on Ubuntu
    	sudo echo "listen_addresses = '*'" >> /etc/postgresql/10/main/postgresql.conf
    	sudo echo "archive_mode = on " >> /etc/postgresql/10/main/postgresql.conf
    	sudo echo "archive_command = 'rsync -a %p barman@192.168.42.101:/var/lib/barman/ssh-progedo/incoming/%f '" >> /etc/postgresql/10/main/postgresql.conf
	sudo echo "password_encryption = scram-sha-256" >> /etc/postgresql/10/main/postgresql.conf
    	# open connection for user barman on Ubuntu
    	sudo echo "host     all     barman     192.168.42.101/32      scram-sha-256" >>/etc/postgresql/10/main/pg_hba.conf
    	sudo echo "host     replication     streaming_barman     192.168.42.101/32      scram-sha-256" >>/etc/postgresql/10/main/pg_hba.conf
	sudo echo "host     replication     repuser     192.168.42.103/32      scram-sha-256" >>/etc/postgresql/10/main/pg_hba.conf
    
    	# Restart Postgresql
    	sudo systemctl restart postgresql@10-main
	
	# Pgbench
	sudo -iu postgres pgbench -i postgres
	sudo -iu postgres pgbench -T 30 postgres

    	# Create user barman and streaming_barman and repuser
    	sudo -iu postgres psql -c "create user barman superuser password 'barman';create user streaming_barman replication password 'streaming_barman';create user repuser replication password 'repuser'"

	# Create file .pgpass
	echo "*:*:*:barman:barman" >> /var/lib/postgresql/.pgpass
	echo "*:*:*:streaming_barman:streaming_barman" >> /var/lib/postgresql/.pgpass
	echo "*:*:*:repuser:repuser" >> /var/lib/postgresql/.pgpass

	chmod 600 /var/lib/postgresql/.pgpass
	chown postgres:postgres /var/lib/postgresql/.pgpass

    	# Create directory and set ssh for barman-postgres comunication in Ubuntu
    	mkdir /var/lib/postgresql/.ssh
    	cat /vagrant/files/id_rsa.pub >> /var/lib/postgresql/.ssh/authorized_keys
    	cp /vagrant/files/id_rsa /var/lib/postgresql/.ssh/
    	chown -R postgres:postgres /var/lib/postgresql/.ssh

	# Create a known_host file on the two machines
	sudo -iu postgres ssh-keyscan -H 192.168.42.101 >> /var/lib/postgresql/.ssh/known_hosts
	sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@192.168.42.101 "ssh-keyscan -H 192.168.42.102 >> /var/lib/barman/.ssh/known_hosts"
	
	# Create a barman slot for the streaming configuration
        sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@192.168.42.101 "barman check progedo-server"
	sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@192.168.42.101 "barman receive-wal --create-slot progedo-server"
	
elif [ "$HOSTNAME" = "pg02" ];then
    
    	# Add Repo
    	sudo add-apt-repository 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main'

	# Import the repository signing key
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
		sudo apt-key add -

	# Update the package lists
	sudo apt-get update

	# Install Postgresql
	sudo apt install postgresql-10 -y
	

	sudo systemctl stop postgresql@10-main

	# Open listen_addresses on Ubuntu
	sudo echo "listen_addresses = '*'" >> /etc/postgresql/10/main/postgresql.conf
	sudo echo "archive_mode = on " >> /etc/postgresql/10/main/postgresql.conf
	sudo echo "archive_command = ':' " >> /etc/postgresql/10/main/postgresql.conf
	# delete data directory
	sudo rm -r /var/lib/postgresql/10/main/*	
	
	# Create directory and set ssh for barman-postgres comunication in Ubuntu
    	mkdir /var/lib/postgresql/.ssh
    	cat /vagrant/files/id_rsa.pub >> /var/lib/postgresql/.ssh/authorized_keys
    	cp /vagrant/files/id_rsa /var/lib/postgresql/.ssh/
    	chown -R postgres:postgres /var/lib/postgresql/.ssh

	# Create file .pgpass
	echo "*:*:*:barman:barman" >> /var/lib/postgresql/.pgpass
	echo "*:*:*:streaming_barman:streaming_barman" >> /var/lib/postgresql/.pgpass
	echo "*:*:*:repuser:repuser" >> /var/lib/postgresql/.pgpass

	chmod 600 /var/lib/postgresql/.pgpass
	chown postgres:postgres /var/lib/postgresql/.pgpass
	# Create a known_host file on the two machines
	sudo -iu postgres ssh-keyscan -H 192.168.42.101 >> /var/lib/postgresql/.ssh/known_hosts
	sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@192.168.42.101 "ssh-keyscan -H 192.168.42.103 >> /var/lib/barman/.ssh/known_hosts"
	# Force wal, create backup and recover
	sudo -iu postgres ssh barman@192.168.42.101 "barman switch-wal --force --archive --archive-timeout 120 progedo-server"
	sudo -iu postgres ssh barman@192.168.42.101 "barman backup progedo-server"
	sudo -iu postgres ssh barman@192.168.42.101 "barman recover progedo-server latest /var/lib/postgresql/10/main/ --remote-ssh-command 'ssh postgres@192.168.42.103' --get-wal"
	
	# Modify recovery.conf
	sudo echo "standby_mode = 'on'" > /var/lib/postgresql/10/main/recovery.conf
	sudo echo "primary_conninfo = 'host=192.168.42.102 user=repuser' " >> /var/lib/postgresql/10/main/recovery.conf
	sudo echo "restore_command = 'barman-wal-restore -U barman 192.168.42.101 progedo-server %f %p'" >> /var/lib/postgresql/10/main/recovery.conf

	# Install barman.cli
	sudo apt install barman.cli -y
	
	# Restart Postgresql
	sudo systemctl start postgresql@10-main

fi
