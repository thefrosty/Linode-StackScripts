#!/bin/bash
#<UDF name="pihole_password" label="PiHole password" default="" description="PiHole web UI password" />
#<UDF name="wg_host" label="WireGuard host" default="" description="Server IP address" />
#<UDF name="wg_password" label="WireGuard password" default="" description="WireGuard password" />
#<UDF name="mysql_password" label="MySQL password" default="" description="Nginx Proxy Manager DB password" />
#<UDF name="mysql_user" label="MySQL username" default="" description="Nginx Proxy Manager DB username" />

sleep 5s

# Pre-requisites and Docker
sudo apt-get update &&
	sudo apt-get install -yqq \
		curl \
		git \
		apt-transport-https \
		ca-certificates \
		gnupg-agent \
		software-properties-common

# Install Docker repository and keys for Ubuntu 22
# https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
	$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update && apt-cache policy docker-ce
sudo apt install docker-ce docker-ce-cli containerd.io -yqq

# Docker should now be installed, the daemon started, and the process enabled to start on boot. Check that it’s running:
sudo systemctl status docker

# Docker Compose
mkdir -p ~/.docker/cli-plugins/
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.10.2/docker-compose-$(uname -s)-$(uname -m)" -o ~/.docker/cli-plugins/docker-compose
sudo chmod +x ~/.docker/cli-plugins/docker-compose
docker compose version

# Portainer -LOCATION -> host-ip:9000
docker volume create portainer_data
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

# WireHole
git clone https://github.com/NOXCIS/wirehole.git
cd wirehole &&
echo "#######################################################################"
echo "|WireHole"
echo "#######################################################################"
sed -i "s/New_York/Los_Angeles" docker-compose.yml
sed -i "s/WEBPASSWORD: \"\"/WEBPASSWORD: \"$PIHOLE_PASSWORD\"" docker-compose.yml
#sleep 3s nano docker-compose.yml
docker compose up --detach &&

# WireGuard Easy -LOCATION -> host-ip:51821 -LOGIN changeme * can be change in portainer env variables.
mkdir ~/.wg-easy
cd ~/.wg-easy &&
wget https://raw.githubusercontent.com/NOXCIS/wg-easy/master/docker-compose.yml
echo "#######################################################################"
echo "|WireGuard UI"
echo "#######################################################################"
if [ -z "${WG_HOST}" ]; then
    $WG_HOST=$(dig +short txt ch whoami.cloudflare @1.0.0.1)
fi
sed -i "s/change.to.host.public.address/$WG_HOST" docker-compose.yml
sed -i "s/changeme/$WG_PASSWORD" docker-compose.yml
#sleep 3s nano docker-compose.yml
docker compose up --detach &&

# Nginx Proxy Manager - LOGIN admin@example.com: changeme
mkdir ~/.nginx-proxy-manager
cd ~/..nginx-proxy-manager &&
wget https://raw.githubusercontent.com/NOXCIS/Docker-nginx-proxy-manager/main/docker-compose.yml
echo "#######################################################################"
echo "|Nginx Proxy Manager"
echo "#######################################################################"
sed -i "s/exampleuser/$MYSQL_USER/" docker-compose.yml
sed -i "s/changeme/$MYSQL_PASSWORD/" docker-compose.yml
#sleep 3s nano docker-compose.yml
docker compose up --detach &&

# WatchTower
docker run -d \
	--name watchtower \
	-v /var/run/docker.sock:/var/run/docker.sock \
	containrrr/watchtower

# Swapfile (for low memory servers)
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
cp /etc/fstab /etc/fstab.bak
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sysctl vm.swappiness=10
sysctl vm.vfs_cache_pressure=50
echo "#######################################################################"
echo " COPY LINES BELOW TO BOTTOM OF FILE THAT WILL BE OPENED. SAVE AND EXIT"
echo "#######################################################################"
echo " vm.swappiness=10 "
echo " vm.vfs_cache_pressure=50 "
echo "########################################################################"
sleep 10s
sudo nano /etc/sysctl.conf
