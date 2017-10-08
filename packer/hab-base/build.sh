#!/usr/bin/env bash

# Build packer image, decrypting and removing key files across runs
gpg -o - -d keys.tar.gz.gpg | tar xz && packer build image.json
rm -rf keys
