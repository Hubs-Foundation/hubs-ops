#!/usr/bin/env bash

# Build packer image, decrypting and removing key files across runs
gpg2 -o - -d secrets.tar.gz.gpg | tar xz && packer build image.json
rm -rf secrets
