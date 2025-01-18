#!/bin/bash
#(awk '{ print $2 }' /var/log/installer/media-info )
rep=""
pakete=""
service="" #be careful not fully implemented now!
remove=""   

# Add fastly repository
if ! grep fastly.linuxmint.io /etc/apt/sources.list.d/official-package-repositories.list
then
	sudo sed -i '/^deb http:\/\/packages.linuxmint.com xia main upstream import backport.*$/ideb http:\/\/fastly.linuxmint.io xia main upstream import backport' /etc/apt/sources.list.d/official-package-repositories.list
fi
#Add other mirrors if timezone is Europe/Berlin
if grep Europe/Berlin /etc/timezone
then	
	if ! grep ftp-stud.hs-esslingen.de /etc/apt/sources.list.d/official-package-repositories.list
	then
		if ! grep -e ftp.uni-mainz.de -e ftp.rrzn.uni-hannover.de /etc/apt/sources.list.d/official-package-repositories.list
		then
			sudo sed -i '/^deb http:\/\/archive.ubuntu.com\/ubuntu noble main restricted universe multiverse$/ideb http:\/\/ftp.uni-mainz.de\/ubuntu noble main restricted universe multiverse\ndeb http:\/\/ftp.uni-mainz.de\/ubuntu noble-updates main restricted universe multiverse\ndeb http:\/\/ftp.uni-mainz.de\/ubuntu noble-backports main restricted universe multiverse\ndeb http:\/\/ftp-stud.hs-esslingen.de\/ubuntu noble main restricted universe multiverse\ndeb http:\/\/ftp-stud.hs-esslingen.de\/ubuntu noble-updates main restricted universe multiverse\ndeb http:\/\/ftp-stud.hs-esslingen.de\/ubuntu noble-backports main restricted universe multiverse\ndeb http:\/\/ftp.rrzn.uni-hannover.de\/pub\/mirror\/linux\/ubuntu noble main restricted universe multiverse\ndeb http:\/\/ftp.rrzn.uni-hannover.de\/pub\/mirror\/linux\/ubuntu noble-updates main restricted universe multiverse\ndeb http:\/\/ftp.rrzn.uni-hannover.de\/pub\/mirror\/linux\/ubuntu noble-backports main restricted universe multiverse' /etc/apt/sources.list.d/official-package-repositories.list
		fi
		if ! grep ftp.rz.uni-frankfurt.de /etc/apt/sources.list.d/official-package-repositories.list
		then
			sudo sed -i '/^deb http:\/\/packages.linuxmint.com xia main upstream import backport.*$/ideb https:\/\/ftp-stud.hs-esslingen.de\/pub\/Mirrors\/packages.linuxmint.com xia main upstream import backport\ndeb https:\/\/ftp.rz.uni-frankfurt.de\/pub\/mirrors\/linux-mint\/packages xia main upstream import backport' /etc/apt/sources.list.d/official-package-repositories.list
		fi
	fi
fi
for i in $(ls /home); do
	if [ $i != "lost+found" ]		
	then
		#autostart
		#sudo mkdir -p /home/$i/.config/autostart/
		#sudo cp -rf $config/.config/autostart/* /home/$i/.config/autostart/
		sudo rm /home/$i/.config/autostart/redshift-gtk.desktop
		#sudo chown -R $i:$i /home/$i	
	fi
done

sudo nala purge -y $remove redshift-gtk

read -p "Do you want to apply the in 22.sh introduced settings? Then press y!"
#	echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	#hide Dayon Assistant
	sudo update-alternatives --set x-terminal-emulator /usr/bin/konsole
	dconf write /org/cinnamon/desktop/applications/terminal/exec "'konsole'"
	dconf load /org/cinnamon/desktop/peripherals/touchpad/ < $config/dconf/touchpad.conf
	dconf load /org/nemo/desktop/ < $config/dconf/desktop.conf
	#<super>L = locking screen
	dconf load /org/cinnamon/desktop/keybindings/ < $config/dconf/keybindings.conf
	dconf write /org/cinnamon/desktop/wm/preferences/num-workspaces 2
	dconf write /org/cinnamon/desktop/interface/gtk-theme "'Mint-Y-Dark-Aqua'"
	#Auto-Update
	if grep "Linux Mint" /etc/issue
	then 
		sudo mintupdate-automation upgrade enable
		sudo mintupdate-automation blacklist enable
		if ! grep "firefox" /etc/mintupdate.blacklist
		then
			sudo su -c 'echo "firefox" >> /etc/mintupdate.blacklist'
		fi
		sudo mintupdate-automation autoremove enable
		#flatpack and cinnamon-spices autoupdates and Hiding linuxmint updates when not necessary
		dconf load /com/linuxmint/updates/ < $config/dconf/linuxmint-updates.conf
	else
		sudo dpkg-reconfigure -plow unattended-upgrades
		sudo cp -f $config/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
	fi
	sudo cp -f $config/firefoxUpdateOnShutdown.service /etc/systemd/system/firefoxUpdateOnShutdown.service
	sudo systemctl daemon-reload
	sudo systemctl enable firefoxUpdateOnShutdown.service
	#Enable guest user
	declare file=/etc/lightdm/lightdm.conf
	if [ -f $file ] 
	then
		if grep "allow-guest=" /etc/lightdm/lightdm.conf
		then 
			sudo sed -i 's/^.*allow-guest=.*$/allow-guest=true/' /etc/lightdm/lightdm.conf
		else
			echo "/etc/lightdm/lightdm.conf exists but allow-guest not. To prevent messing up things I do nothing."
		fi
	else
		sudo cp $config/etc/lightdm/lightdm.conf /etc/lightdm/
	fi
fi

dconf write /org/cinnamon/settings-daemon/plugins/color/night-light-enabled true
dconf write /org/cinnamon/settings-daemon/plugins/color/night-light-temperature 'uint32 1700'

sudo nala install --fix-broken -y

#Hardware probe
sudo nala install -y --no-install-recommends hw-probe
sudo -E hw-probe -all -upload
sudo nala purge -y hw-probe

#Aufräumen
#rm -rf $verzeichnis/Install-Skript
