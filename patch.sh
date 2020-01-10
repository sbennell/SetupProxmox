#!/usr/bin/env bash

mkdir -p /usr/share/pve-patch/{images,scripts}
echo "- patch `pveversion`..."
echo "- download and copy files..."
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/master/images/favicon.ico
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/master/images/logo-128.png
wget -nc -qP /usr/share/pve-patch/images/ https://raw.githubusercontent.com/sbennell/pve-patch/master/images/proxmox_logo.png
rm -f /usr/share/pve-patch/scripts/{90pvepatch,apply.sh,pvebanner}
wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/pve-patch/master/scripts/{90pvepatch,apply.sh,pvebanner}
chmod -R a+x /usr/share/pve-patch/scripts
cp -f /usr/share/pve-patch/scripts/90pvepatch /etc/apt/apt.conf.d/90pvepatch
cp -f /usr/share/pve-patch/scripts/pvebanner /usr/bin/pvebanner
/usr/share/pve-patch/scripts/apply.sh
echo "- Apt Update and upgrade system..."
apt update
apt upgrade -y
echo "- Install ifupdown2..."
apt install ifupdown2 -y
echo "- Updating Name..."
x="Proxmox Virtual Environment"
y="Bennell IT Virtual Environment"
sed -i -e "s/$x/$y/g" /usr/share/pve-manager/index.html.tpl
sed -i -e "s/$x/$y/g" /usr/share/pve-manager/touch/index.html.tpl

w="Proxmox VE"
e="Bennell IT VE "
sed -i -e "s/$w/$e/g" /usr/share/pve-manager/js/pvemanagerlib.js
echo "- done!"
