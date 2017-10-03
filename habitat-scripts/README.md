# Habitat Scripts

Scripts for setting up a temporary development environment for janus.

## Usage

Generate dtls certs in this folder:

```
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:1024 -keyout dtls.key -out dtls.pem
```

Run hab studio with `hab studio enter`.

Once inside hab studio run `./configure.sh` to configure.

Change config.toml to override any plan config specified [here](https://github.com/mozilla/socialmr/blob/habitat-plans/janus-dependencies/projects/habitat-plans/janus-gateway/habitat/default.toml).