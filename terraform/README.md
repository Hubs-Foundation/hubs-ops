Terraform scripts to set up AWS infrastructure, meant to be used with [terragrunt](https://github.com/gruntwork-io/terragrunt).

Currently the entire system is managed by terraform except for the SSL certs (which must be manually uploaded to the AWS Certificate Manager.)

Experimental Let's Encrypt support available in the runbook in `../ansible/update_ssl.sh` which should be able to generate an updated cert and land it onto ACM and the Janus services.
