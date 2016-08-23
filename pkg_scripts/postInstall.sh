#!/bin/sh

# This doesnt belong here, but I cannot figure out where it goes
# and how other files have it set.
chmod +x /opt/spinnaker/install/first_google_boot.sh

# Deprecated. Will be removed in the future.
if [ `readlink -f /opt/spinnaker/scripts` != "/opt/spinnaker/bin" ]; then
  ln -s /opt/spinnaker/bin /opt/spinnaker/scripts
fi

# get spinnaker jenkins password from vault
pass=$(curl vault.vertigo.stitchfix.com/secure/spinnaker_jenkins_password)
sed -i s/"password: {{ JENKINS_PASSWORD_HERE }}"/"password: $pass"/g /opt/spinnaker/config/default-spinnaker-local.yml

# get oauth secret from vault
secret=$(curl vault.vertigo.stitchfix.com/secure/spinnaker_oauth_secret)
sed -i s/"clientSecret:"/"clientSecret: $secret"/g /opt/spinnaker/config/gate-googleOAuth.yml

# get keystore password for x509 auth from vault
keystore_pass=$(curl vault.vertigo.stitchfix.com/secure/spinnaker_keystore_password)
sed -i s/"keyStorePassword:"/"keyStorePassword: $keystore_pass"/g /opt/spinnaker/config/gate-local.yml
sed -i s/"trustStorePassword:"/"trustStorePassword: $keystore_pass"/g /opt/spinnaker/config/gate-local.yml

# add the server.crt into the global java keystore
/usr/lib/jvm/java/bin/keytool -import -noprompt -trustcacerts -alias server -file /opt/spinnaker/ssl/server.crt -keystore cacerts

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

ln -s /etc/nginx/sites-available/spinnaker.conf /etc/nginx/sites-enabled/spinnaker.conf

service sf-nginx restart

# Rename the other packer package that conflicts with our packer...(this is hacky)
mv /usr/sbin/packer /usr/sbin/packer.io

# now put our sudo wrapper on packer command (HACK!)
# echo 'sudo /usr/bin/packer "$@"' > /usr/bin/_packer
# chmod 755 /usr/bin/_packer

# add spinnaker to sudoers file
echo 'spinnaker ALL=(ALL) NOPASSWD: /usr/bin/packer' > /etc/sudoers.d/spinnaker

# Install cassandra keyspaces
cqlsh cassandra.vertigo.stitchfix.com -f "/opt/spinnaker/cassandra/create_echo_keyspace.cql"
cqlsh cassandra.vertigo.stitchfix.com -f "/opt/spinnaker/cassandra/create_front50_keyspace.cql"
cqlsh cassandra.vertigo.stitchfix.com -f "/opt/spinnaker/cassandra/create_rush_keyspace.cql"

# Disable auto upstart of the services.
# We'll have spinnaker auto start, and start them as it does.
#for s in clouddriver orca front50 rush rosco echo gate igor; do
#    echo manual | sudo tee /etc/init/$s.override
#done
