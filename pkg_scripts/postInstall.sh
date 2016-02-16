#!/bin/sh

# This doesnt belong here, but I cannot figure out where it goes
# and how other files have it set.
chmod +x /opt/spinnaker/install/first_google_boot.sh

# Deprecated. Will be removed in the future.
if [ `readlink -f /opt/spinnaker/scripts` != "/opt/spinnaker/bin" ]; then
  ln -s /opt/spinnaker/bin /opt/spinnaker/scripts
fi

if [ ! -f /opt/spinnaker/config/spinnaker-local.yml ]; then
  # Create master config on original install, but leave in place on upgrades.
  cp /opt/spinnaker/config/default-spinnaker-local.yml /opt/spinnaker/config/spinnaker-local.yml
fi

# deck settings
/opt/spinnaker/bin/reconfigure_spinnaker.sh

# vhosts
rm -rf /etc/nginx/sites-enabled/*.conf

ln -s /etc/nginx/sites-available/spinnaker.conf /etc/nginx/sites-enabled/spinnaker.conf

service sf-nginx restart

# Install the correct packer libs
mkdir /tmp/packer && pushd /tmp/packer
curl -L -O https://releases.hashicorp.com/packer/0.8.6/packer_0.8.6_linux_amd64.zip
unzip -u -o -q packer_0.8.6_linux_amd64.zip -d /usr/bin
popd
rm -rf /tmp/packer

# Rename the other packer package that conflicts with our packer...(this is hacky)
mv /usr/sbin/packer /usr/sbin/packer.io

# Install cassandra keyspaces
cqlsh -f "/opt/spinnaker/cassandra/create_echo_keyspace.cql"
cqlsh -f "/opt/spinnaker/cassandra/create_front50_keyspace.cql"
cqlsh -f "/opt/spinnaker/cassandra/create_rush_keyspace.cql"

# Make cassandra start on bootup
chkconfig --add cassandra
# Start all the services

# start 'clouddriver'
# start 'orca'
# start 'front50'
# start 'rush'
# start 'rosco'
# start 'echo'
# start 'gate'
# start 'igor'


