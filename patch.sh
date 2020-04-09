#!/usr/bin/env bash

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
echo "- Apt Update and upgrade system..."
apt update
apt upgrade -y
echo "- Install ifupdown2..."
apt install ifupdown2 -y
cp -f /usr/share/pve-patch/scripts/pvebanner /usr/bin/pvebanner
/usr/share/pve-patch/scripts/apply.sh

mkdir -p ~/.ssh 

touch ~/.ssh/authorized_keys

echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLEFMCtuN6KUoDQl3MPhFfkXE38D1AqSyjqBdtBnMAP6PbEipkLWNhUJ4dvtnOct4GtCTe73FJRrNzt6HnS6A69PbZ2KkODH6ju0d0yUWitsyasH5Ui38EwraxQ13swIFsdisGOfdm17tPifHLKdU+LDu67yb8g6M0W8265h63gNSkPNN6IKczGQBTjo2QyZxy4uARiq16VT4NVa+E8y6bisQMi088AyY/bYsKfrFRSDUWpJmnJp85fhs8tRFT17SnRBfXf9YsRiBLAFRQdk1Jout8E3UB1gKLJ/1xTjLLB5ujDKzX4RcZRglKKor+NVYH/1IZfdwidHILT/z8IRJbmZP4EdTwAplFou2tiVJyufCBkve+1oqlsJ+dnnwIthQfBuP6DMmq+n2Ba8vYlaMSO2dkNXeINCK3WWEEqJElQoAPNwtYeZ9QrXb+/kIGU1bZ35ieBz6V/HNAgpbit8TwGescM6B/vyg2q5qm2l8mAI6ltIGH4touBGb4nx01lsQx2oev3dBJcXMZZLh/dpbZQnxjKgxK8UqY/dS2LhP2zANUVHe607bdYRy8MdmQclbemKLkVy5xT6UnAd0MmnoDdiwUahez0+VSEhHMA8qju4t1p4OwxzrCLjjt5H5mcimnEM9TzxlwdCx3S3Wjo051u63x6qr6iJsMnZ1PqEFAew== sb >> ~/.ssh/authorized_keys

chmod -R go= ~/.ssh

echo "- done!"
