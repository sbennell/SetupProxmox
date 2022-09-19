#!/usr/bin/env bash -ex
set -euo pipefail
shopt -s inherit_errexit nullglob
YW=`echo "\033[33m"`
BL=`echo "\033[36m"`
RD=`echo "\033[01;31m"`
BGN=`echo "\033[4;92m"`
GN=`echo "\033[1;92m"`
DGN=`echo "\033[32m"`
CL=`echo "\033[m"`
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
branches=master
my $year = `date +%Y`;

clear
echo -e "${BL}This script will Perform Post Install Routines.${CL}"
while true; do
    read -p "Start the Proxmox Post Install Script From Bennell IT (y/n)?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
if [ `pveversion | grep "pve-manager/7" | wc -l` -ne 1 ]; then
        echo -e "\n${RD}⚠ This version of Proxmox Virtual Environment is not supported"
        echo -e "Requires PVE Version: 7.XX${CL}"
        echo -e "\nExiting..."
        sleep 3
        exit
fi
function header_info {
echo -e "${RD}
888888b.                                       888 888     8888888 88888888888
888  "88b                                      888 888       888       888
888  .88P                                      888 888       888       888
8888888K.   .d88b.  88888b.  88888b.   .d88b.  888 888       888       888
888  "Y88b d8P  Y8b 888 "88b 888 "88b d8P  Y8b 888 888       888       888
888    888 88888888 888  888 888  888 88888888 888 888       888       888
888   d88P Y8b.     888  888 888  888 Y8b.     888 888       888       888
8888888P"   "Y8888  888  888 888  888  "Y8888  888 888     8888888     888
                              www.bennellit.com.au                        $year
${CL}"
}

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}
clear

header_info
read -r -p "Disable Enterprise Repository? <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
msg_info "Disabling Enterprise Repository"
sleep 2
sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list
msg_ok "Disabled Enterprise Repository"
fi

read -r -p "Add Bennell IT subscription Licence <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
msg_info "Add Bennell IT subscription Licence"
/usr/share/pve-patch/scripts/subscription.sh
wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/scripts/70BITsubscription
sleep 2
msg_ok "Added Bennell IT subscription Licence"
fi

read -r -p "Add Bennell IT SSH Key <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
msg_info "Adding SSH Key - Bennell IT..."
mkdir -p ~/.ssh 
touch ~/.ssh/authorized_keys
echo ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAkXk0+tC1ZMiWgTQvE/GeB9+TuPWTf8mr9zVOYdNhF+KFXxc/DjMjIPNCAUxtQErlush1GF87b7gaEIC2F5p/+xr39gnt5panjT2AJmVQm9GrSc0LwZOHducgB9SeW7F6A2hA0dtEDxOPHC88ipT9qvTZdeC+mgoNmyIAIMmnPVcZOqQm7iVUf3kJCRWVGI/csE1UYpZ1tLpkaNqjP0Iy7cQvNgodJWh8Mg//TD6ESKBQ35P3+6zT2zEpIK/hQ5eaW5Uu82kSt1ZGuNaPukfCra0cjWr2n4hC+C3E9m3K/3ZV43usaxwSbPa6R/jJE4fyqpC2hqdTKW8Z66mVTC8EpQ== Bennell IT >> ~/.ssh/authorized_keys
chmod -R go= ~/.ssh
sleep 2
msg_ok "Added SSH Key - Bennell IT"
fi

read -r -p "Add and Enable Dark Mode  <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
msg_info "Adding Dark Mode"
wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/scripts/80DarkMode
/usr/share/pve-patch/scripts/darkmode.sh
sleep 2
msg_ok "Enabled Dark Mode"
fi


mkdir -p /usr/share/pve-patch/{images,scripts}
echo "- Proxmox Setup Script $branches Version..."
echo "- patch `pveversion`..."
echo "- download and copy files..."
rm -f /usr/share/pve-patch/images/{favicon.ico,logo-128.png,proxmox_logo.png}
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/images/favicon.ico
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/images/logo-128.png
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/images/proxmox_logo.png
rm -f /usr/share/pve-patch/scripts/{90pvepatch,apply.sh,pvebanner}
wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/scripts/{darkmode.sh,subscription.sh,apply.sh,pvebanner}
chmod -R a+x /usr/share/pve-patch/scripts
cp -f /usr/share/pve-patch/scripts/90pvepatch /etc/apt/apt.conf.d/90pvepatch
chmod +x /usr/share/pve-patch/scripts/apply.sh
/usr/share/pve-patch/scripts/apply.sh


echo "- Apt Update and upgrade system..."
echo ""
apt update && apt dist-upgrade -y
echo "- Install Packages."
apt install ifupdown2 sasl2-bin mailutils libsasl2-modules curl -y 


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
