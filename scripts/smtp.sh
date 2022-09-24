if [ $(dpkg-query -W -f='${Status}' libsasl2-modules 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
				  apt-get install -yqq libsasl2-modules;
			fi
			if [ $(dpkg-query -W -f='${Status}' mailutils 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
				  apt-get install -yqq mailutils;
			fi
			clear
			ALIASESBCK=/etc/aliases.BCK
			if test -f "$ALIASESBCK"; then
				echo "backup OK"
				else
				cp -n /etc/aliases /etc/aliases.BCK
			fi
			MAINCFBCK=/etc/postfix/main.cf.BCK
			if test -f "$MAINCFBCK"; then
				echo "backup OK"
				else
				cp -n /etc/postfix/main.cf /etc/postfix/main.cf.BCK
			fi
      
      varrootmail=$(whiptail --inputbox "System administrator recipient mail address (user@domain.tld) (root alias)" 8 39 noreply@bennellit.com.au --title "System administrator recipient mail address" 3>&1 1>&2 2>&3)

      varmailserver=$(whiptail --inputbox "What is the mail server hostname?" 8 39 smtp.office365.com --title "mail server hostname" 3>&1 1>&2 2>&3)

      varmailport=$(whiptail --inputbox " What is the mail server port? (Usually 587 - can be 25 (no tls))" 8 39 smtp.office365.com --title "mail server Port" 3>&1 1>&2 2>&3)

      read -p  "- Does the server require TLS? y = yes / anything = no: " -n 1 -r 
      
      if (whiptail --title "require TLS?" --yesno "Does the server require TLS?" 8 78); then
          vartls=yes
      else
          vartls=no
      fi

      varmailusername=$(whiptail --inputbox "What is the AUTHENTIFICATION USERNAME? (user@domain.tld or username)?" 8 39 noreply@bennellit.com.au --title "Email Address" 3>&1 1>&2 2>&3)

      varmailpassword=$(whiptail --passwordbox "What is the AUTHENTIFICATION PASSWORD" 8 78 --title "Email Password" 3>&1 1>&2 2>&3)


      if (whiptail --title "SENDER mail address" --yesno "Is the SENDER mail address the same as the AUTHENTIFICATION USERNAME?" 8 78); then
          varsenderaddress=$varmailusername
      else
          varsenderaddress=$(whiptail --inputbox "What is the sender email address? " 8 39 noreply@bennellit.com.au --title "Email Address" 3>&1 1>&2 2>&3)
      fi

      echo " "
      echo "- Working on it!"
      echo " "
      echo "- Setting Aliases"
      if grep "root:" /etc/aliases
      	then
					echo "- Alias entry was found: editing for $varrootmail"
					sed -i "s/^root:.*$/root: $varrootmail/" /etc/aliases
				else
					echo "- No root alias found: Adding"
					echo "root: $varrootmail" >> /etc/aliases
				fi
				
      #Setting canonical file for sender - :
      echo "root $varsenderaddress" > /etc/postfix/canonical
      chmod 600 /etc/postfix/canonical
				
      # Preparing for password hash
      echo [$varmailserver]:$varmailport $varmailusername:$varmailpassword > /etc/postfix/sasl_passwd
      chmod 600 /etc/postfix/sasl_passwd 
				
      # Add mailserver in main.cf
      sed -i "/#/!s/\(relayhost[[:space:]]*=[[:space:]]*\)\(.*\)/\1"[$varmailserver]:"$varmailport""/"  /etc/postfix/main.cf
				
      # Checking TLS settings
      echo "- Setting correct TLS Settings: $vartls"
      postconf smtp_use_tls=$vartls
				
      # Checking for password hash entry
      if grep "smtp_sasl_password_maps" /etc/postfix/main.cf
      then
      echo "- Password hash already setted-up"
      else
        echo "- Adding password hash entry"
        postconf smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd
      fi
      #checking for certificate
      if grep "smtp_tls_CAfile" /etc/postfix/main.cf
        then
				echo "- TLS CA File looks setted-up"
				else
				postconf smtp_tls_CAfile=/etc/ssl/certs/ca-certificates.crt
			fi
      # Adding sasl security options
      # eliminates default security options which are imcompatible with gmail
			if grep "smtp_sasl_security_options" /etc/postfix/main.cf
			  then
			  echo "- Google smtp_sasl_security_options setted-up"
				else
				postconf smtp_sasl_security_options=noanonymous
			fi
			if grep "smtp_sasl_auth_enable" /etc/postfix/main.cf
			  then
			  echo "- Authentification already enabled"
			  else
			  postconf smtp_sasl_auth_enable=yes
			fi 
			if grep "sender_canonical_maps" /etc/postfix/main.cf
			  then
			  echo "- Canonical entry already existing"
			  else
			  postconf sender_canonical_maps=hash:/etc/postfix/canonical
			fi 
				
			echo "- Encrypting password and canonical entry"
			postmap /etc/postfix/sasl_passwd
			postmap /etc/postfix/canonical
			echo "- Restarting postfix and enable automatic startup"
			systemctl restart postfix && systemctl enable postfix
			echo "- Cleaning file used to generate password hash"
			rm -rf "/etc/postfix/sasl_passwd"
			echo "- Files cleaned"
