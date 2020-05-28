#!/usr/bin/env bash

echo "- Apt Update and upgrade system..."
apt update
apt upgrade -y
echo "- Install ifupdown2..."
apt install ifupdown2 -y

mkdir -p /usr/share/pve-patch/{images,scripts}
echo "- patch `pveversion`..."
echo "- download and copy files..."
rm -f /usr/share/pve-patch/scripts/{favicon.ico,logo-128.png,proxmox_logo.png}
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/master/images/favicon.ico
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/master/images/logo-128.png
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/master/images/proxmox_logo.png
rm -f /usr/share/pve-patch/scripts/{90pvepatch,apply.sh,pvebanner}
wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/pve-patch/master/scripts/{90pvepatch,apply.sh,pvebanner}
chmod -R a+x /usr/share/pve-patch/scripts
cp -f /usr/share/pve-patch/scripts/90pvepatch /etc/apt/apt.conf.d/90pvepatch
cp -f /usr/share/pve-patch/scripts/pvebanner /usr/bin/pvebanner
/usr/share/pve-patch/scripts/apply.sh

echo "- Adding SSH Key - Bennell IT..."
mkdir -p ~/.ssh 
touch ~/.ssh/authorized_keys
echo ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAkXk0+tC1ZMiWgTQvE/GeB9+TuPWTf8mr9zVOYdNhF+KFXxc/DjMjIPNCAUxtQErlush1GF87b7gaEIC2F5p/+xr39gnt5panjT2AJmVQm9GrSc0LwZOHducgB9SeW7F6A2hA0dtEDxOPHC88ipT9qvTZdeC+mgoNmyIAIMmnPVcZOqQm7iVUf3kJCRWVGI/csE1UYpZ1tLpkaNqjP0Iy7cQvNgodJWh8Mg//TD6ESKBQ35P3+6zT2zEpIK/hQ5eaW5Uu82kSt1ZGuNaPukfCra0cjWr2n4hC+C3E9m3K/3ZV43usaxwSbPa6R/jJE4fyqpC2hqdTKW8Z66mVTC8EpQ== Bennell IT >> ~/.ssh/authorized_keys
chmod -R go= ~/.ssh

echo "- Seting up smtp for email alerts"
apt install postfix sasl2-bin mailutils -y
apt install libsasl2-modules -y
wget --user=bennellit --ask-password -qP /etc/postfix/ https://bennellit.com.au/Files/noaccess/{mailtest.txt,main.cf,sasl_passwd.db,sender_canonical.db}
service postfix restart
sendmail -v server@lab-network.xyz

echo "- done!"
