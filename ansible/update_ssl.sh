#!/usr/bin/env bash

# TODO this is not used, re-visit when Let's Encrypt supports wildcard SSL
# certificates (Jan 2018)

# The certificate we are using for *.reticulum is a namecheap cert purchased
# that expires in Oct 2018
echo "TODO revisit this once Let's Encrypt supports wildcard SSL certificates"
exit 1

# update_ssl.sh - Updates the Let's Encrypt wildcard certificate 

ansible-vault decrypt --output=tmp/letsencrypt.pem roles/ssl/files/letsencrypt.pem 
openssl req -nodes -newkey rsa:2048 -keyout tmp/reticulum.io.pem -out tmp/reticulum.io.csr -subj "/C=US/ST=Greg Fodor/L=Mountain View/O=Mozilla/OU=Mixed Reality/CN=reticulum.io"
ansible-playbook --ask-vault-pass -i "localhost," -c local ssl.yml

# TODO once new certificate is obtained it needs to be saved off into the
# roles\ret\files directory (and a ret config deploy needs to be run.)

trap 'rm -rf tmp/*' INT TERM HUP EXIT
