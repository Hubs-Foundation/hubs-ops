#!/usr/bin/env bash

# TODO this is not used, re-visit when Let's Encrypt supports wildcard SSL certificates.
echo "TODO revisit this once Let's Encrypt supports wildcard SSL certificates"
exit 1

ansible-vault decrypt --output=tmp/letsencrypt.pem roles/ssl/files/letsencrypt.pem 
openssl req -nodes -newkey rsa:2048 -keyout tmp/reticulum.io.pem -out tmp/reticulum.io.csr -subj "/C=US/ST=Greg Fodor/L=Mountain View/O=Mozilla/OU=Mixed Reality/CN=reticulum.io"
ansible-playbook --ask-vault-pass -i "localhost," -c local ssl.yml

trap 'rm -rf tmp/*' INT TERM HUP EXIT
