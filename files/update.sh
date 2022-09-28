echo "- Updating System"
apt-get update -y -qq
apt-get upgrade -y -qq
apt-get dist-upgrade -y -qq

echo "- Updating pvebanner"
if [ ! -f /usr/share/pve-patch/en-pvebanner ]; then
  rm /usr/bin/pvebanner
  wget -qP /usr/bin/ https://raw.githubusercontent.com/sbennell/pve-patch/master/files/pvebanner 
  chmod +x /usr/bin/pvebanner
  /usr/bin/pvebanner
		else
		echo "- pvebanner is not enabled"
		fi
