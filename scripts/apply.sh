#!/usr/bin/env bash

DEBIAN_CODENAME=`cat /etc/os-release | grep VERSION_CODENAME | cut -d "=" -f2`
ENTERPRISE_REPO_LIST="/etc/apt/sources.list.d/pve-enterprise.list"
FREE_REPO_LIST="/etc/apt/sources.list.d/pve.list"
FREE_REPO_LINE="deb http://download.proxmox.com/debian/pve $DEBIAN_CODENAME pve-no-subscription"

function pve_patch() {
  echo "- apply patch..."
  echo $FREE_REPO_LINE > $FREE_REPO_LIST
  [ -f $ENTERPRISE_REPO_LIST ] && mv $ENTERPRISE_REPO_LIST $ENTERPRISE_REPO_LIST~
  cp --backup /usr/share/pve-patch/images/* /usr/share/pve-manager/images/
}

pve_patch
cp -f /usr/share/pve-patch/scripts/pvebanner /usr/bin/pvebanner
echo "- Updating logon banner..."
/usr/bin/pvebanner

bash <(curl -s https://raw.githubusercontent.com/sbennell/PVEDiscordDark/master/PVEDiscordDark.sh ) install
