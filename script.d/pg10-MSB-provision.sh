#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export HOSTNAME=$(hostname)
export IP_BARMAN="192.168.42.100"
export IP_PG01="192.168.42.101"
export IP_PG02="192.168.42.102"


ssh_keys_exchanger () {

USER=$1
HOME=$2

if [ ! -d "${HOME}/.ssh" ]; then
  sudo mkdir "${HOME}/.ssh"
fi

# ssh access granted between virtual machines
sudo cat /vagrant/files/id_rsa.pub >> ${HOME}/.ssh/authorized_keys
sudo cp /vagrant/files/id_rsa ${HOME}/.ssh/
sudo chown -R ${USER}:${USER} ${HOME}/.ssh
}

add_pgdg_repo () {
# Add PostgreSQL10 apt repository on Ubuntu
sudo add-apt-repository 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main'

# Import the repository signing key
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Update the package lists
sudo apt update
}


install_configure_barman () {
# Install barman
sudo apt install barman -y

# Copy barman configuration files
sudo cp /vagrant/files/progedo-server.conf /etc/barman.d/
#cp /vagrant/files/ssh-server.conf /etc/barman.d/
#cp /vagrant/files/streaming-server.conf /etc/barman.d/
sudo chown barman:barman /etc/barman.d/*

# Create .pgpass file
sudo cat > /var/lib/barman/.pgpass <<EOF
*:*:*:barman:barman
*:*:*:streaming_barman:streaming_barman
EOF

sudo chmod 600 /var/lib/barman/.pgpass
sudo chown barman:barman /var/lib/barman/.pgpass
}


install_postgres () {
# Install Postgresql
sudo apt install postgresql-10 -y

# Install Barman Cli
sudo apt install barman.cli -y
}

configure_postgres () {
# Set configuration file
sudo cat >> /etc/postgresql/10/main/postgresql.conf <<EOF
listen_addresses = '*'
archive_mode = on
archive_command = 'rsync -a %p barman@${IP_BARMAN}:/var/lib/barman/progedo-server/incoming/%f '
password_encryption = scram-sha-256
EOF

# Set HBA connections
sudo cat >> /etc/postgresql/10/main/pg_hba.conf <<EOF
host     all             barman               ${IP_BARMAN}/32      scram-sha-256
host     replication     streaming_barman     ${IP_BARMAN}/32      scram-sha-256
host     replication     repuser              ${IP_PG02}/32      scram-sha-256
EOF

# Create .pgpass file
sudo cat > /var/lib/postgresql/.pgpass <<EOF
*:*:*:barman:barman
*:*:*:streaming_barman:streaming_barman
*:*:*:repuser:repuser
EOF

sudo chmod 600 /var/lib/postgresql/.pgpass
sudo chown postgres:postgres /var/lib/postgresql/.pgpass
}

create_users () {
# Create users
sudo -iu postgres psql <<EOF
CREATE USER barman SUPERUSER PASSWORD 'barman';
CREATE USER streaming_barman REPLICATION PASSWORD 'streaming_barman';
CREATE USER repuser REPLICATION PASSWORD 'repuser'
EOF
}

restart_postgres () {
# Restart PostgreSQL
sudo systemctl restart postgresql@10-main
}

make_some_noise () {
# Pgbench
sudo -iu postgres pgbench -i postgres
sudo -iu postgres pgbench -T 30 postgres
}

create_rep_slot () {
# Create a barman slot for the streaming configuration
#sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@${IP_BARMAN} "barman check progedo-server"
sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@${IP_BARMAN} "barman receive-wal --create-slot progedo-server"
}

grant_ssh_access () {

IP_PG=$1

# Create a known_host file on the two machines
sudo -iu postgres ssh-keyscan -H ${IP_BARMAN} >> /var/lib/postgresql/.ssh/known_hosts
sudo -iu postgres ssh -o StrictHostKeyChecking=no barman@${IP_BARMAN} "ssh-keyscan -H ${IP_PG} >> /var/lib/barman/.ssh/known_hosts"
}

create_standby () {
# Stop PostgreSQL
sudo systemctl stop postgresql@10-main

# Clean data directory
sudo rm -rf /var/lib/postgresql/10/main/*

# Create backup
sudo -iu postgres ssh barman@${IP_BARMAN} <<EOF
barman switch-wal --force --archive --archive-timeout 120 progedo-server
barman backup progedo-server
EOF

# Create restore
sudo -iu postgres ssh barman@${IP_BARMAN} "barman recover progedo-server latest /var/lib/postgresql/10/main/ --remote-ssh-command 'ssh postgres@${IP_PG02}' --get-wal"

# Create recovery.conf
cat > /var/lib/postgresql/10/main/recovery.conf <<EOF
standby_mode = 'on'
primary_conninfo = 'host=${IP_PG01} user=repuser'
restore_command = 'barman-wal-restore -U barman ${IP_BARMAN} progedo-server %f %p'
EOF

# Start Standby
sudo systemctl start postgresql@10-main
}

#### Start provisioning

## Does not make any sense
#if [ ! -d "/root/.ssh" ];then
#    sudo mkdir /root/.ssh
#fi
#
#sudo cp .ssh/authorized_keys /root/.ssh/


case ${HOSTNAME} in

  barman)
    echo "Install and configure Barman..."
    ssh_keys_exchanger vagrant "/home/vagrant"
    add_pgdg_repo
    install_configure_barman
    ssh_keys_exchanger barman "/var/lib/barman"
    ;;
  pg01)
    echo "Install and configure Master..."
    ssh_keys_exchanger vagrant "/home/vagrant"
    add_pgdg_repo
    install_postgres
    configure_postgres
    ssh_keys_exchanger postgres "/var/lib/postgresql"
    grant_ssh_access ${IP_PG01}
    restart_postgres
    create_users
    create_rep_slot
    ;;
  pg02)
    echo "Install and configure Standby..."
    ssh_keys_exchanger vagrant "/home/vagrant"
    add_pgdg_repo
    install_postgres
    configure_postgres
    ssh_keys_exchanger postgres "/var/lib/postgresql"
    grant_ssh_access ${IP_PG02}
    create_standby
    ;;

esac
