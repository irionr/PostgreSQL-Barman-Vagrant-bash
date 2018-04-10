#!/bin/bash

# Create directory and set ssh to have root access
if [ ! -d "/root/.ssh" ];then
    sudo mkdir /root/.ssh
fi
sudo cp .ssh/authorized_keys /root/.ssh/

#if [ "$HOSTNAME" = "pg01" ];then

    # Add Repo
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
    sudo echo "archive_command = ':' " >> /etc/postgresql/10/main/postgresql.conf

    # Restart Postgresql
    sudo systemctl restart postgresql@10-main

#fi

