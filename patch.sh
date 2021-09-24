#!/usr/bin/env bash

branches=master

mkdir -p /usr/share/pve-patch/{images,scripts}
echo "- Proxmox Setup Script Testing Version..."
echo "- patch `pveversion`..."
echo "- download and copy files..."
rm -f /usr/share/pve-patch/images/{favicon.ico,logo-128.png,proxmox_logo.png}
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/images/favicon.ico
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/images/logo-128.png
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/images/proxmox_logo.png
rm -f /usr/share/pve-patch/scripts/{90pvepatch,apply.sh,pvebanner}
wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/scripts/{90pvepatch,apply.sh,pvebanner}
chmod -R a+x /usr/share/pve-patch/scripts
cp -f /usr/share/pve-patch/scripts/90pvepatch /etc/apt/apt.conf.d/90pvepatch
chmod +x /usr/share/pve-patch/scripts/apply.sh
/usr/share/pve-patch/scripts/apply.sh

curl -s https://api.github.com/repos/sbennell/pve-fake-subscription/releases/latest \
| grep "browser_download_url.*deb" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi - 
dpkg -i pve-fake-subscription_*.deb
rm -f pve-fake-subscription_*.deb

echo "127.0.0.1 shop.maurer-it.com" | tee -a /etc/hosts

echo "- Apt Update and upgrade system..."
echo ""
apt update
apt update && apt dist-upgrade -y
echo "- Install Packages."
apt install ifupdown2 sasl2-bin mailutils libsasl2-modules curl -y 

echo "- Adding SSH Key - Bennell IT..."
mkdir -p ~/.ssh 
touch ~/.ssh/authorized_keys
echo ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAkXk0+tC1ZMiWgTQvE/GeB9+TuPWTf8mr9zVOYdNhF+KFXxc/DjMjIPNCAUxtQErlush1GF87b7gaEIC2F5p/+xr39gnt5panjT2AJmVQm9GrSc0LwZOHducgB9SeW7F6A2hA0dtEDxOPHC88ipT9qvTZdeC+mgoNmyIAIMmnPVcZOqQm7iVUf3kJCRWVGI/csE1UYpZ1tLpkaNqjP0Iy7cQvNgodJWh8Mg//TD6ESKBQ35P3+6zT2zEpIK/hQ5eaW5Uu82kSt1ZGuNaPukfCra0cjWr2n4hC+C3E9m3K/3ZV43usaxwSbPa6R/jJE4fyqpC2hqdTKW8Z66mVTC8EpQ== Bennell IT >> ~/.ssh/authorized_keys
chmod -R go= ~/.ssh

echo "- Setting  up smtp for email alerts"
#remove file if exists
rm -f /etc/postfix/{main.cf,emailsetupinfo.txt,sasl_passwd,sender_canonical}
#Downloading Files
wget -nc -qP /etc/postfix/ https://raw.githubusercontent.com/sbennell/pve-patch/master/mail/main.cf

echo "Enter Office 365 Email Address?"
read Email

echo "Enter Office 365 Email Password?"
read Password

echo "[smtp.office365.com]:587 $Email:$Password" >> /etc/postfix/sasl_passwd
echo "/.+/ $Email" >> /etc/postfix/sender_canonical

postmap hash:/etc/postfix/sasl_passwd
postmap hash:/etc/postfix/sender_canonical
chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db  
chmod 644 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db  
chown root:root /etc/postfix/sender_canonical /etc/postfix/sender_canonical.db  
chmod 644 /etc/postfix/sender_canonical /etc/postfix/sender_canonical.db
service postfix restart

Serverfqdn=$(hostname -f)
IP=$(hostname -I)

echo "to: server@bennellit.com.au" >> /etc/postfix/emailsetupinfo.txt
echo "subject:New Server Setup Info $Serverfqdn" >> /etc/postfix/emailsetupinfo.txt
echo "Hostname: $Serverfqdn" >> /etc/postfix/emailsetupinfo.txt
echo "IP Address: $IP" >> /etc/postfix/emailsetupinfo.txt

sendmail -v server@lab-network.xyz < /etc/postfix/emailsetupinfo.txt

echo "- done!"
