echo "- Setting  up smtp for email alerts"
#remove file if exists
rm -f /etc/postfix/{main.cf,mailtest.txt,sasl_passwd,sender_canonical}
#Downloading Files
wget -nc -qP /etc/postfix/ https://raw.githubusercontent.com/sbennell/pve-patch/master/mail/main.cf

#echo "Enter Office 365 Email Address?"
read Email

#echo "Enter Office 365 Email Password?"
read Password

echo "[smtp.office365.com]:587 $Email:$Password" >> /etc/postfix/sasl_passwd
echo "/.+/ $Email" >> /etc/postfix/sender_canonical

postmap hash:/etc/postfix/sasl_passwd
postmap hash:/etc/postfix/sender_canonical
cp /etc/ssl/certs/thawte_Primary_Root_CA.pem /etc/postfix/cacert.pem
chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db  
chmod 644 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db  
chown root:root /etc/postfix/sender_canonical /etc/postfix/sender_canonical.db  
chmod 644 /etc/postfix/sender_canonical /etc/postfix/sender_canonical.db
service postfix restart

Serverfqdn=$(hostname -f)
IP=$(hostname -I)

echo "to: server@bennellit.com.au" >> /etc/postfix/emailsetupinfo.txt
echo "subject:New Server Setup Info $Serverfqdn" >> /etc/postfix/emailsetupinfo.txt
echo "Hostname: $Serverfqdn" >> /etc/postfix/emailsetupinfo.txt
echo "IP Address: $IP" >> /etc/postfix/emailsetupinfo.txt

sendmail -v server@lab-network.xyz < /etc/postfix/emailsetupinfo.txt

echo "- done!"
