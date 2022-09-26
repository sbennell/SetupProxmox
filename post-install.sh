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


result=$(whoami)
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
		msg_ok "Disabled Enterprise Repository"
	;;

	"2)")   
	    msg_info "Adding Beta/Test Repository and set disabled"
		cat <<EOF >> /etc/apt/sources.list
		# deb http://download.proxmox.com/debian/pve bullseye pvetest
		EOF
		sleep 2
		msg_ok "Added Beta/Test Repository"
    ;;

	"3)")   
        msg_info "Updating Proxmox VE 7 (Patience)"
		apt-get update &>/dev/null
		apt-get -y dist-upgrade &>/dev/null
		msg_ok "Updated Proxmox VE 7 (⚠ Reboot Recommended)"
        ;;

	"4)")   
		msg_info "Adding Bennell IT subscription Licence"
		rm -f /etc/apt/apt.conf.d/70BITsubscription
		wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/scripts/subscription.sh
		chmod +x /usr/share/pve-patch/scripts/subscription.sh
		/usr/share/pve-patch/scripts/subscription.sh &
		#wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/apt.conf.d/70BITsubscription
		sleep 2
		msg_ok "Added Bennell IT subscription Licence"
	;;

	"5)")   
		msg_info "Adding Bennell IT Logon Banner"
		rm -f /etc/apt/apt.conf.d/90pvebanner
		wget -qP /usr/share/pve-patch/scripts/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/scripts/pvebanner.sh
		chmod +x /usr/share/pve-patch/scripts/pvebanner.sh
		/usr/share/pve-patch/scripts/pvebanner.sh &
		wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/apt.conf.d/90pvebanner
		sleep 2
		msg_ok "Added Bennell IT Logon Banner"
	;;
		
	"6)")   
		msg_info "Adding SSH Key - Bennell IT..."
		mkdir -p ~/.ssh  &>/dev/null
		touch ~/.ssh/authorized_keys &>/dev/null
		echo ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAkXk0+tC1ZMiWgTQvE/GeB9+TuPWTf8mr9zVOYdNhF+KFXxc/DjMjIPNCAUxtQErlush1GF87b7gaEIC2F5p/+xr39gnt5panjT2AJmVQm9GrSc0LwZOHducgB9SeW7F6A2hA0dtEDxOPHC88ipT9qvTZdeC+mgoNmyIAIMmnPVcZOqQm7iVUf3kJCRWVGI/csE1UYpZ1tLpkaNqjP0Iy7cQvNgodJWh8Mg//TD6ESKBQ35P3+6zT2zEpIK/hQ5eaW5Uu82kSt1ZGuNaPukfCra0cjWr2n4hC+C3E9m3K/3ZV43usaxwSbPa6R/jJE4fyqpC2hqdTKW8Z66mVTC8EpQ== Bennell IT >> ~/.ssh/authorized_keys  &>/dev/null
		chmod -R go= ~/.ssh  &>/dev/null
		sleep 2
		msg_ok "Added SSH Key - Bennell IT"	
	;;

	"7)")   
		msg_info "Adding Dark Mode"
		rm -f /etc/apt/apt.conf.d/80DarkMode
		wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/SetupProxmox/master/apt.conf.d/80DarkMode 
		bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install &>/dev/null
		sleep 2
		msg_ok "Enabled Dark Mode"
	;;
		
	"8)")   
		msg_info "Running 365 SMTP Setup"
		bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/SetupProxmox/scripts/smtp.sh ) install &>/
		sleep 2
		msg_ok "SMTP Setup Done"
	;;

	"9)")   
		msg_info "Rebooting Proxmox VE 7"
		sleep 2
		msg_ok "Completed Post Install Routines"
		reboot
	;;
		
	"E)") 
		msg_ok "Completed Post Install Routines"
		exit
	;;
		
esac
whiptail --msgbox "$result" 20 78
done
exit
