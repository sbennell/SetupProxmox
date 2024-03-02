# SetupProxmox

Removes subscription dialogs, replaces enterprise repository with non-subscription repository, apt Update and apt upgrade system, Add Benenell IT SSh Key and Configure Postfix to use Office365 SMTP Relay. For PVE 8.x Tested on PVE up to 8.1.4


Use at your own risk! Read the script before you run it. 

## Install

1. Connect to node via SSH
2. Run
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/sbennell/SetupProxmox/master/proxmox_toolbox.sh)"
```

## Other Scripts

Proxmox CPU Scaling Governor
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/misc/scaling-governor.sh)"

```

## Restore/Enable Enterprise repository

```
sed -i "s/^#deb/deb/g" /etc/apt/sources.list.d/pve-enterprise.list
```

## Remove Bennell IT subscription Licence 

```
apt purge pve-bit-subscription
```
