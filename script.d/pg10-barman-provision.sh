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
#If you want to select the machine by the OS installed : VERSION=$(cat /etc/issue | cut -d \  -f1)
#-if [ "$VERSION" = "Ubuntu" ];then

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

else
    # add PostgreSQL repository

    # If CentOS
    # sudo yum install https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm -y
    # install pg10
    # sudo yum install postgresql10 -y
    # sudo yum install postgresql10-server -y
    # initdb
    # sudo /usr/pgsql-10/bin/postgresql-10-setup initdb
    # sudo systemctl enable postgresql-10
    # sudo systemctl start postgresql-10

    # If Ubuntu
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
    sudo echo "archive_command = 'rsync -a %p barman@192.168.42.101:/var/lib/barman/ssh-progedo/incoming/%f ' " >> /etc/postgresql/10/main/postgresql.conf

    # open connection for user barman on Ubuntu
    sudo echo "host     all     barman     192.168.42.101/32      trust" >>/etc/postgresql/10/main/pg_hba.conf
    sudo echo "host     replication     streaming_barman     192.168.42.101/32      trust" >>/etc/postgresql/10/main/pg_hba.conf
    # Restart Postgresql
    sudo systemctl restart postgresql@10-main


    #create user barman and streaming_barman
    sudo -iu postgres psql -c "create user barman superuser;create user streaming_barman replication"

    # Create directory and set ssh for barman-postgres comunication in Ubuntu
    mkdir /var/lib/postgresql/.ssh
    cat /vagrant/files/id_rsa.pub >> /var/lib/postgresql/.ssh/authorized_keys
    cp /vagrant/files/id_rsa /var/lib/postgresql/.ssh/
    chown -R postgres:postgres /var/lib/postgresql/.ssh


    # Create a known_host file on the two machines
    sudo -iu postgres ssh-keyscan -H 192.168.42.101 >> /var/lib/postgresql/.ssh/known_hosts
    sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@192.168.42.101 "ssh-keyscan -H 192.168.42.102 >> /var/lib/barman/.ssh/known_hosts"
    # create a barman slot for the streaming configuration
    sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@192.168.42.101 "barman check progedo-server"
    sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@192.168.42.101 "barman receive-wal --create-slot progedo-server"	
    sudo -iu postgres ssh barman@192.168.42.101 "barman switch-wal --force --archive progedo-server"

fi



