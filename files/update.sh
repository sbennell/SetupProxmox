echo "- Updating System"
apt-get update -y -qq
apt-get upgrade -y -qq
apt-get dist-upgrade -y -qq

echo "- Updating pvebanner"
if [ ! -f /usr/share/pve-patch/enable/pvebanner ]; then
  echo "- pvebanner is not enabled"
else
  rm /usr/bin/pvebanner
  wget -qP /usr/bin/ https://raw.githubusercontent.com/sbennell/pve-patch/master/files/pvebanner 
  chmod +x /usr/bin/pvebanner
  /usr/bin/pvebanner
fi

echo "- Updating Bennell IT subscription Licence"
if [ ! -f /usr/share/pve-patch/enable/BITsubscription ]; then
  echo "- Bennell IT subscription Licence is not enabled"
else
  apt purge pve-bit-subscription -y -qq
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
fi

echo "- Updating Dark Mode"
if [ ! -f /usr/share/pve-patch/enable/darkmode ]; then
  echo "- Dark Mode is not enabled"
else
  wget -qO - https://raw.githubusercontent.com/sbennell/PVEDiscordDark/master/PVEDiscordDark.sh | bash /dev/stdin update
fi
