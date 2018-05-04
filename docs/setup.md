https://www.habitat.sh/docs/install-habitat/
or

# create hab user
sudo useradd -m hab

# Install hab
curl https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.sh | sudo bash

sudo nohup hab sup run &

# Use mozillareality PostgreSQL until 10.3 upgraded
sudo hab svc start mozillareality/postgresql

# Create ret_dev db
sudo $(hab pkg path mozillareality/postgresql)/bin/createdb -Uadmin ret_dev

# Create self signed SSL cert
openssl req -newkey rsa:2048 -nodes -keyout ssl.key -x509 -days 365 -out ssl.cert

# Start reticulum
sudo hab svc start mozillareality/reticulum
