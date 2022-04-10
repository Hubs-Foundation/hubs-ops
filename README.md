# Hubs by Mozilla Ops

This repo contains all the necessary scripts and tools for standing up infrastructure for Hubs by Mozilla on AWS.

## Contents:

### `ansible` - Contains scripts for performing configuration deploys to the live Habitat ring, and other runbooks.

### `bin` - Useful scripts for managing Hubs services

Expects ssh-agent to have mozilla mr ssh key registered and present in `~/.ssh/mozilla_mr_id_rsa`.

host-types can be any ansible role such as: `bots`, `discord`, `janus`, `migrate`, `postgrest`, `ret`, and `ssl`. Or `ci`.

hostnames can be any server host name such as: `quixotic-duck`

environments include: `prod` and `dev`

See the top of each script for usage instructions.

### `helpers.sh` - Functions for managing Hubs services.
  
Load in your `.bashrc` or `.zshrc` file by adding `source ~/path/to/hubs-ops/helpers.sh`

Expects an ssh config in `~/.ssh/config` like the following:

```
Host *.reticulum.io
User ubuntu
PreferredAuthentications publickey,keyboard-interactive
IdentityFile ~/.ssh/mozilla_mr_id_rsa
ForwardAgent yes
```

See the `helpers.sh` source for more documenation on each command.

Useful commands include:

- `moz-ec2 [env] [asg]`
  Lists active hosts from EC2, displaying environment, ASG, name, private IP, and public IP.
- `moz-ssh target ...cmd-args`
  SSHes into the given target through its bastion host, e.g. `moz-ssh dazzling-druid`.
- `moz-admin`
  Opens an SSH tunnel to the prod Postgrest admin console.
- `moz-admin-dev`
  Opens an SSH tunnel to the dev Postgrest admin console.
- `moz-iex target ...cmd-args`
  SSHes into a Reticulum host and opens an Elixir console.
- `moz-ci`
  Creates a tunnel to the CI host's web interface on port 8088.
- `moz-scp env ...scp-args`
  Proxies SCP over a bastion host, e.g. `moz-scp prod dazzling-druid-local.reticulum.io:~/core core`.

### `packer` - Packer AMI definitions

### `plans` - Habitat plans

### `terraform` - Terraform + terragrunt scripts


