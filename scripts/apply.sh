#!/usr/bin/env bash

DEBIAN_CODENAME=`cat /etc/os-release | grep VERSION_CODENAME | cut -d "=" -f2`
ENTERPRISE_REPO_LIST="/etc/apt/sources.list.d/pve-enterprise.list"
FREE_REPO_LIST="/etc/apt/sources.list.d/pve.list"
FREE_REPO_LINE="deb http://download.proxmox.com/debian/pve $DEBIAN_CODENAME pve-no-subscription"

function pve_patch() {
  echo "- apply patch..."
  echo $FREE_REPO_LINE > $FREE_REPO_LIST
  [ -f $ENTERPRISE_REPO_LIST ] && mv $ENTERPRISE_REPO_LIST $ENTERPRISE_REPO_LIST~
  sed -i.bak "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
  cp --backup /usr/share/pve-patch/images/* /usr/share/pve-manager/images/
}

pve_patch
echo "- Updating logon banner..."
/usr/bin/pvebanner

echo "- Updating Name..."
x="Proxmox Virtual Environment"
y="Bennell IT Virtual Environment"
sed -i -e "s/$x/$y/g" /usr/share/pve-manager/index.html.tpl
sed -i -e "s/$x/$y/g" /usr/share/pve-manager/touch/index.html.tpl

w="Proxmox VE"
e="Bennell IT VE "
sed -i -e "s/$w/$e/g" /usr/share/pve-manager/js/pvemanagerlib.js
