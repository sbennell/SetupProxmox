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

clear
if [ `pveversion | grep "pve-manager/7" | wc -l` -ne 1 ]; then
        echo -e "\n${RD}⚠ This version of Proxmox Virtual Environment is not supported"
        echo -e "Requires PVE Version: 7.XX${CL}"
        echo -e "\nExiting..."
        sleep 3
        exit
fi
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

update () {
		# Check if the /usr/bin/proxmox-update entry for update is already created
		if [ ! -f /usr/bin/proxmox-update ]; then
			echo "- Retreiving new bin"
			wget -qO "/usr/bin/proxmox-update"  https://raw.githubusercontent.com/sbennell/SetupProxmox/Testing/files/proxmox-update && chmod +x "/usr/bin/proxmox-update"
			update
		else
		echo "- Updating System"
			apt-get update -y -qq
			apt-get upgrade -y -qq
			apt-get dist-upgrade -y -qq
		fi
}

if  [[ $1 = "-u" ]]; then
	update
exit
fi
	
function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

header_info

mkdir -p /usr/share/pve-patch/{images,scripts}

clear

while [ 1 ]
do
CHOICE=$(
whiptail --title "Proxmox Post Install Script" --menu "Make your choice" 16 100 9 \
	"1)" "Configure sources for no-enterprise repository"   \
	"2)" "Add (Disabled) Beta/Test Repository" \
	"3)" "Update Proxmox VE 7 now? " \
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
        msg_info "Updating Proxmox VE 7 (Patience)"
		apt-get update -y -qq
		apt-get upgrade -y -qq
		apt-get dist-upgrade -y -qq
		msg_ok "Updated Proxmox VE 7 (⚠ Reboot Recommended)"
        ;;

	"4)")   
		msg_info "Adding Bennell IT subscription Licence"
		rm -f /etc/apt/apt.conf.d/70BITsubscription
		wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/scripts/subscription.sh
		chmod +x /usr/share/pve-patch/scripts/subscription.sh
		/usr/share/pve-patch/scripts/subscription.sh &
		#wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/apt.conf.d/70BITsubscription
		whiptail --msgbox "Added Bennell IT subscription Licence" 20 78
	;;

	"5)")   
		msg_info "Adding Bennell IT Logon Banner"
		rm -f /etc/apt/apt.conf.d/90pvebanner
		wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/scripts/pvebanner.sh
		chmod +x /usr/share/pve-patch/scripts/pvebanner.sh
		/usr/share/pve-patch/scripts/pvebanner.sh &
		wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/apt.conf.d/90pvebanner
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
		rm -f /etc/apt/apt.conf.d/80DarkMode
		wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/apt.conf.d/80DarkMode 
		bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install &>/dev/null
		whiptail --msgbox "Enabled Dark Mode" 20 78
	;;
		
	"8)")   
		msg_info "Running 365 SMTP Setup"
		bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/SetupProxmox/scripts/smtp.sh ) install &>/
		whiptail --msgbox "SMTP Setup Done" 20 78
	;;

	"9)")   
		msg_info "Rebooting Proxmox VE 7"
		reboot
	;;
		
	"E)") 
		whiptail --msgbox "Completed Post Install Routines" 20 78
		exit
	;;
		
esac

done
exit
