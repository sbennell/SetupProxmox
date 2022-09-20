apt purge pve-fake-subscription &>/dev/null
curl -s https://api.github.com/repos/sbennell/pve-fake-subscription/releases/latest \
| grep "browser_download_url.*deb" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi - 
dpkg -i pve-fake-subscription_*.deb &>/dev/null
rm -f pve-fake-subscription_*.deb &>/dev/null
echo "127.0.0.1 shop.maurer-it.com" | tee -a /etc/hosts &>/dev/null
