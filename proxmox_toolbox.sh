#!/usr/bin/env bash -ex
# check if root 1
if [[ $(id -u) -ne 0 ]] ; then echo "- Please run as root / sudo" ; exit 1 ; fi

# -----------------ENVIRONNEMENT VARIABLES----------------------
set -euo pipefail

shopt -s inherit_errexit nullglob
YW=`echo "\033[33m"`
RD=`echo "\033[01;31m"`
GN=`echo "\033[1;92m"`
CL=`echo "\033[m"`
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"

pve_log_folder="/var/log/pve/tasks/"
distribution=$(. /etc/*-release;echo $VERSION_CODENAME)
hostname=$(hostname)
date=$(date +%Y_%m_%d-%H_%M_%S)

# ---------------END OF ENVIRONNEMENT VARIABLES-----------------

update () {
		# Check if the /usr/bin/proxmox-update entry for update is already created
		if [ ! -f /usr/bin/proxmox-update ]; then
			echo "- Retreiving new bin"
			wget -qO "/usr/bin/proxmox-update"  https://raw.githubusercontent.com/bennell/proxmox_toolbox/main/bin/proxmox-update && chmod +x "/usr/bin/proxmox-update"
			update
		else
		echo "- Updating System"
			apt-get update -y -qq
			apt-get upgrade -y -qq
			apt-get dist-upgrade -y -qq
			if grep -Ewqi "no-subscription" /etc/apt/sources.list; then
				if grep -q ".data.status.toLowerCase() == 'active') {" $proxmoxlib; then
						echo "- Subscription Message already removed - Skipping"
					else
				fi
			fi
		fi
}

function header_info {
echo -e "${RD}
    ____                                 __    __           ____  ______
   / __ )  ___    ____    ____   ___    / /   / /          /  _/ /_  __/
  / __  | / _ \  / __ \  / __ \ / _ \  / /   / /           / /    / /   
 / /_/ / /  __/ / / / / / / / //  __/ / /   / /          _/ /    / /    
/_____/  \___/ /_/ /_/ /_/ /_/ \___/ /_/   /_/          /___/   /_/   
                     www.bennellit.com.au                        
                 Proxmox Post Install Script
${CL}"
sleep 5
}

snmpconfig() {
wget -qO /etc/snmp/snmpd.conf https://github.com/sbennell/proxmox_toolbox/raw/main/snmp/snmpd.conf
}

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

header_info

clear
if [ `pveversion | grep "pve-manager/7" | wc -l` -ne 1 ]; then
        echo -e "\n${RD}⚠ This version of Proxmox Virtual Environment is not supported"
        echo -e "Requires PVE Version: 7.XX${CL}"
        echo -e "\nExiting..."
        sleep 3
        exit
fi

update

msg_info "Running System Updates"
apt-get update -y -qq
apt-get upgrade -y -qq
apt-get dist-upgrade -y -qq
		
mkdir -p /usr/share/pve-patch/enable

clear

while [ 1 ]
do
CHOICE=$(
whiptail --title "Proxmox Post Install Script" --menu "Make your choice" 16 100 9 \
	"1)" "Configure sources for no-enterprise repository"   \
	"2)" "Add (Disabled) Beta/Test Repository" \
	"3)" "Install usefull dependencies" \
	"4)" "Add Bennell IT subscription Licence" \
	"5)" "Add Bennell IT Logon Banner" \
	"6)" "Add Bennell IT SSH Key <y/N>" \
	"7)" "Add and Enable Dark Mode" \
	"8)" "setup SMTP" \
	"9)" "Reboot Host" \
	"E)" "Exit"  3>&2 2>&1 1>&3	
)


case $CHOICE in
	"1)")   
		msg_info "Configure sources for no-enterprise repository"
		sleep 2
		
		if [ -d "$pve_log_folder" ]; then
			echo "- Server is a PVE host"
			echo "- Checking Sources list"
			if grep -Fq "deb http://download.proxmox.com/debian/pve" /etc/apt/sources.list; then
				echo "-- Source looks alredy configured - Skipping"
			else
				echo "-- Adding new entry to sources.list"
				sed -i "\$adeb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" /etc/apt/sources.list
			fi
		echo "- Checking Enterprise Source list"
		if grep -Fq "#deb https://enterprise.proxmox.com/debian/pve" /etc/apt/sources.list.d/pve-enterprise.list; then
			echo "-- Entreprise repo looks already commented - Skipping"
		else
			echo "-- Hiding Enterprise sources list"
			sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
		fi
		else
		echo "- Server is a PBS host"
		echo "- Checking Sources list"
		if grep -Fq "deb http://download.proxmox.com/debian/pbs" /etc/apt/sources.list; then
			echo "-- Source looks alredy configured - Skipping"
		else
			echo "-- Adding new entry to sources.list"
			sed -i "\$adeb http://download.proxmox.com/debian/pbs $distribution pbs-no-subscription" /etc/apt/sources.list
		fi
		echo "- Checking Enterprise Source list"
		if grep -Fq "#deb https://enterprise.proxmox.com/debian/pbs" /etc/apt/sources.list.d/pbs-enterprise.list; then
			echo "-- Entreprise repo looks already commented - Skipping"
		else
			echo "-- Hiding Enterprise sources list"
			sed -i 's/^/#/' /etc/apt/sources.list.d/pbs-enterprise.list
		fi
	fi
		whiptail --msgbox "Disabled Enterprise Repository" 20 78
	;;

	"2)")   
	    msg_info "Adding Beta/Test Repository and set disabled"
		if [ -d "$pve_log_folder" ]; then
			echo "- Server is a PVE host"
			echo "- Checking Sources list"
			if grep -Fq "deb http://download.proxmox.com/debian/pve $distribution pvetest" /etc/apt/sources.list; then
				echo "-- Source looks alredy configured - Skipping"
			else
				echo "-- Adding new entry to sources.list"
				sed -i "\$a#deb http://download.proxmox.com/debian/pve $distribution pvetest" /etc/apt/sources.list
			fi
		else
		echo "- Server is a PBS host"
		echo "- Checking Sources list"
		if grep -Fq "deb http://download.proxmox.com/debian/pbs $distribution pbstest" /etc/apt/sources.list; then
			echo "-- pbstest looks alredy configured - Skipping"
		else
			echo "-- Adding pbstest entry to sources.list"
			sed -i "\$a#deb http://download.proxmox.com/debian/pbs $distribution pbstest" /etc/apt/sources.list
		fi
	fi
		whiptail --msgbox "Addied Beta/Test Repository and set disabled" 20 78
	;;

	"3)")   
        msg_info "Install usefull dependencies"
		if [ $(dpkg-query -W -f='${Status}' ifupdown2 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
			apt-get install -y ifupdown2;
		else
			echo "- ifupdown2 already installed"
		fi
		if [ $(dpkg-query -W -f='${Status}' git 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
			apt-get install -y git;
		else
			echo "- git already installed"
		fi
		if [ $(dpkg-query -W -f='${Status}' sudo 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
			apt-get install -y sudo;
		else
			echo "- sudo already installed"
		fi
		if [ $(dpkg-query -W -f='${Status}' libsasl2-modules 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
			apt-get install -y libsasl2-modules;.
		else
			echo "- libsasl2-modules already installed"
		fi

		whiptail --msgbox "Installed usefull dependencies" 20 78
        ;;

	"4)")   
		msg_info "Adding Bennell IT subscription Licence"
		
		if [ $(dpkg-query -W -f='${Status}' pve-bit-subscription 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
			echo "- pve-bit-subscription is not installed"
		else
			echo "- pve-bit-subscription is installed"
			apt purge pve-bit-subscription -y &>/dev/null
		fi
		
		curl -s https://api.github.com/repos/sbennell/pve-bit-subscription/releases/latest \
		| grep "browser_download_url.*deb" \
		| cut -d : -f 2,3 \
		| tr -d \" \
		| wget -qi -
		dpkg -i pve-bit-subscription_*.deb &>/dev/null
		rm -f pve-bit-subscription_*.deb &>/dev/null
    
		if grep -Fq "127.0.0.1 shop.maurer-it.com" /etc/hosts; then
		    echo "-- Check for shop.maurer-it.com block looks alredy configured - Skipping"
		else
		    echo "-- Blocking shop.maurer-it.com "
		    sed -i "\$a127.0.0.1 shop.maurer-it.com $distribution pbstest" /etc/hosts
		fi
		
		whiptail --msgbox "Added Bennell IT subscription Licence" 20 78
	;;

	"5)")   
		msg_info "Adding Bennell IT Logon Banner"
		rm /usr/bin/pvebanner
		wget -qP /usr/bin/ https://raw.githubusercontent.com/sbennell/pve-patch/master/files/pvebanner 
		chmod +x /usr/bin/pvebanner
		/usr/bin/pvebanner
		echo true > /usr/share/pve-patch/enable/pvebanner
		whiptail --msgbox "Added Bennell IT Logon Banner" 20 78
	;;
		
	"6)")   
		msg_info "Adding SSH Key - Bennell IT..."
		mkdir -p ~/.ssh  &>/dev/null
		touch ~/.ssh/authorized_keys &>/dev/null
		echo ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAkXk0+tC1ZMiWgTQvE/GeB9+TuPWTf8mr9zVOYdNhF+KFXxc/DjMjIPNCAUxtQErlush1GF87b7gaEIC2F5p/+xr39gnt5panjT2AJmVQm9GrSc0LwZOHducgB9SeW7F6A2hA0dtEDxOPHC88ipT9qvTZdeC+mgoNmyIAIMmnPVcZOqQm7iVUf3kJCRWVGI/csE1UYpZ1tLpkaNqjP0Iy7cQvNgodJWh8Mg//TD6ESKBQ35P3+6zT2zEpIK/hQ5eaW5Uu82kSt1ZGuNaPukfCra0cjWr2n4hC+C3E9m3K/3ZV43usaxwSbPa6R/jJE4fyqpC2hqdTKW8Z66mVTC8EpQ== Bennell IT >> ~/.ssh/authorized_keys  &>/dev/null
		chmod -R go= ~/.ssh  &>/dev/null
		whiptail --msgbox "Added SSH Key - Bennell IT" 20 78
	;;

	"7)")   
		msg_info "Adding Dark Mode"
		rm -f /usr/share/pve-patch/enable/pvebanner
		wget -qO - https://raw.githubusercontent.com/sbennell/PVEDiscordDark/master/PVEDiscordDark.sh | bash /dev/stdin update
		echo true > /usr/share/pve-patch/enable/pvebanner
		whiptail --msgbox "Enabled Dark Mode" 20 78
	;;
		
	"8)")   
		msg_info "Running 365 SMTP Setup"
		bash <(curl -s https://raw.githubusercontent.com/sbennell/SetupProxmox/Testing/scripts/smtp.sh ) install &>/
		whiptail --msgbox "SMTP Setup Done" 20 78
	;;

	"9)")   
		msg_info "Rebooting Server"
		reboot
	;;
		
	"E)") 
		whiptail --msgbox "Completed Post Install Routines" 20 78
		exit
	;;
		
esac

done
whiptail --msgbox "Completed Post Install Routines" 20 78
exit
