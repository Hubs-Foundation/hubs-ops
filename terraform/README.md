Terraform scripts to set up AWS infrastructure, meant to be used with
[terragrunt](https://github.com/gruntwork-io/terragrunt).

Currently the entire system is managed by terraform except for the SSL
`*.reticulum.io` wildcart cert (which was manually uploaded to the AWS
Certificate Manager.) Once Let's Encrypt supports wildcard certs in Jan
2018 the runbook in `../ansible/update_ssl.sh` should be able to generate
an updated cert and land it onto ACM and the Janus services.
