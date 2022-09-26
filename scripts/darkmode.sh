rm -f  /usr/share/pve-patch/{PVEDiscordDark.sh}
wget -nc -qP /usr/share/pve-patch/scripts https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh
bash /usr/share/pve-patch/scripts/PVEDiscordDark.sh update
