apt purge pve-fake-subscription
curl -s https://api.github.com/repos/sbennell/pve-fake-subscription/releases/latest \
| grep "browser_download_url.*deb" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi - 
dpkg -i pve-fake-subscription_*.deb
rm -f pve-fake-subscription_*.deb
echo "127.0.0.1 shop.maurer-it.com" | tee -a /etc/hosts
wget -qP /etc/apt/apt.conf.d/ https://raw.githubusercontent.com/sbennell/pve-patch/$branches/scripts/70BITsubscription
