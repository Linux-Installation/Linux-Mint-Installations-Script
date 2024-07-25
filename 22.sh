#!/bin/bash
#(awk '{ print $2 }' /var/log/installer/media-info )
rep=""
pakete=""
service="" #be careful not fully implemented now!
remove=""   

sudo apt-get update
sudo apt-get -y dist-upgrade

export DEBIAN_FRONTEND=noninteractive
grep Wilma /etc/issue
if [ $? != 0 ]  
then 
	read -p "Du benutzt kein Linux Mint der Version 22! Wenn du das Script trotzdem fortsetzen möchtest drücke j!"
	echo    # (optional) move to a new line
	if [[ ! $REPLY =~ ^[Jj]$ ]]
	then
    		exit 1
	fi
fi
if [ $(uname -m) = x86_64 ]
then
	Bit=64
elif [ $(uname -m) = i686 ]
then
	Bit=32
else
	echo "Konnte weder eine 32 Bit, noch eine 64 Bit Version vorfinden!"
	echo "Breche ab!"
	exit 1
fi

#https://forums.linuxmint.com/viewtopic.php?t=287026
sudo sed -i "/recordfail_broken=/{s/1/0/}" /etc/grub.d/00_header
sudo update-grub
#Config-Daten
verzeichnis=$(pwd)
config=$(pwd)/download

read -p "Soll das Programm KDE-Connect-Monitor (Zugriff von und aufs Handy) installiert werden? Dann drücke j!"
#echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Jj]$ ]]
then
	pakete=`echo "$pakete kdeconnect"`
	if [ -f "/usr/bin/cinnamon" ] 
	then
		cinnamon-kdeconnect=true
	fi
fi

if [ "$1" = "" ] || [ "$1" = "rep" ]
then
#Kopiere bei Bedarf Firefox, Chromium und gajim Einstellungen
alterUser=`who | awk '{ print $1 }'`

for i in $(ls /home); do
if [ $i != "lost+found" ]		
then
    #dayon
    sudo mkdir -p /home/$i/.dayon
	sudo cp -rf $config/.dayon /home/$i
	#hide Dayon Assistant
	sudo mkdir -p /home/$i/.local/share/applications
	sudo mv $config/.local/share/applications/dayon_assistant.desktop /home/$i/.local/share/applications/
	
	#kdeconnect-cinnamon
	if [ cinnamon-kdeconnect==true ]
	then
		if [ ! -d /home/$i/.config/cinnamon/spices/kdecapplet@joejoetv ] 
		then
			sudo mkdir -p /home/$i/.config/cinnamon/spices/
			sudo cp -rf $config/.config/cinnamon/spices/kdecapplet@joejoetv /home/$i/.config/cinnamon/spices/
		fi
		if [ ! -d /home/$i/.local/share/cinnamon/applets/kdecapplet@joejoetv ] 
		then
			sudo mkdir -p /home/$i/.local/share/cinnamon/applets/
			sudo cp -rf $config/.local/share/cinnamon/applets/kdecapplet@joejoetv /home/$i/.local/share/cinnamon/applets/
		fi
	fi
	#gajim
	declare dir=/home/$i/.config/gajim
	if [ -d $dir ] 
	then
		read -p "Das Verzeichnis .config/gajim existiert schon, soll es überschrieben werden? Dann drücke j!"
	#	echo    # (optional) move to a new line
		if [[ ! $REPLY =~ ^[Jj]$ ]]
		then
			echo "kopiere gajim nicht"
		else
		    overwriteGajim=true
		    sudo rm -rf /home/$i/.config/gajim
		fi
	fi
	if [ ! -d $dir ] || [ overwriteGajim==true ]
	then
		#echo $dir
		sudo mkdir -p /home/$i/.config
		sudo cp -rf $config/.config/gajim /home/$i/.config								 
	fi		
	
	#Google Chrome
	declare dir=/home/$i/.config/google-chrome
	if [ -d $dir ] 
	then
		read -p "Das Verzeichnis .config/google-chrome existiert schon, soll es überschrieben werden? Dann drücke j!"
	#	echo    # (optional) move to a new line
		if [[ ! $REPLY =~ ^[Jj]$ ]]
		then
			echo "kopiere Google Chrome nicht"
		else
		    overwriteChrome=true
		    sudo rm -rf /home/$i/.config/google-chrome
		fi
	fi
	if [ ! -d $dir ] || [ overwriteChrome==true ]
	then
		#echo $dir
		sudo mkdir -p /home/$i/.config
		sudo cp -rf $config/.config/google-chrome /home/$i/.config								 
	fi		
	
	#Vivaldi
	declare dir=/home/$i/.config/vivaldi
	if [ -d $dir ] 
	then
		read -p "Das Verzeichnis .config/vivaldi existiert schon, soll es überschrieben werden? Dann drücke j!"
	#	echo    # (optional) move to a new line
		if [[ ! $REPLY =~ ^[Jj]$ ]]
		then
			echo "kopiere Vivaldi nicht"
		else
		    overwriteChrome=true
		    sudo rm -rf /home/$i/.config/vivaldi
		fi
	fi
	if [ ! -d $dir ] || [ overwriteChrome==true ]
	then
		#echo $dir
		sudo mkdir -p /home/$i/.config
		sudo cp -rf $config/.config/vivaldi /home/$i/.config								 
	fi	
	
	#firefox
	declare dir=/home/$i/.mozilla
	if [ -d $dir ] 
	then
		read -p "Das Verzeichnis Firefox existiert schon, soll es überschrieben werden? Dann drücke j!"
		echo    # (optional) move to a new line
		if [[ ! $REPLY =~ ^[Jj]$ ]]
		then
			echo "kopiere Firefox nicht"
		else
		    overwriteFirefox=true
		    sudo rm -rf /home/$i/.mozilla
		fi
	fi
	if [ ! -d $dir ] || [ overwriteFirefox==true ]
	then
	    #echo $dir
		sudo cp -rf $config/.mozilla /home/$i/
	fi
	#autostart
	sudo mkdir -p /home/$i/.config/autostart/
	sudo cp -rf $config/.config/autostart/* /home/$i/.config/autostart/*
	sudo chown -R $i:$i /home/$i	
fi
done
fi
#Gaming on AMD/Intel
read -p "Möchtest du Games spielen und hast eine AMD/Intel Grafikkarte? Dann drücke j!"
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Jj]$ ]]
then
  sudo add-apt-repository -y ppa:kisak/kisak-mesa
	pakete=`echo "$pakete dxvk mesa-vulkan-drivers mesa-vulkan-drivers:i386"`
fi

#Vivaldi (Chromium based Browser)
read -p "Soll Vivaldi (Chromium based Browser) installiert werden? Dann drücke j!"
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Jj]$ ]]
then
    wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor | sudo dd of=/usr/share/keyrings/vivaldi-browser.gpg
    echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=$(dpkg --print-architecture)] https://repo.vivaldi.com/archive/deb/ stable main" | sudo dd of=/etc/apt/sources.list.d/vivaldi-archive.list
    pakete=`echo "$pakete vivaldi-stable"`
fi


#gajim
read -p "Do you want to install gajim? Then press y!"
#echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Jj]$ ]]
then
	pakete=`echo "$pakete gajim-plugininstaller gajim-rostertweaks gajim-urlimagepreview gajim-omemo"`
	read -p "Soll gajim für alle User automatisch gestartet werden? Dann drücke j!"
    #echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Jj]$ ]]
    then
        sudo sh -c 'echo "[Desktop Entry]" > /etc/xdg/autostart/gajim.desktop'
        sudo sh -c 'echo "Type=gajim" >> /etc/xdg/autostart/gajim.desktop'
        sudo sh -c 'echo "Name=gajim" >> /etc/xdg/autostart/gajim.desktop'
        sudo sh -c 'echo "Exec=gajim" >> /etc/xdg/autostart/gajim.desktop'
    fi
fi

#flathub
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

#Fritz!Box
read -p "Soll das Programm Roger Router (ehemals ffgtk) für die Fritz!Box installiert werden? Dann drücke j!"
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Jj]$ ]]
then
sudo flatpak -y install flathub org.tabos.roger  
fi

#Laptop Akkulaufzeit
read -p "Ist dies ein Laptop? Soll die Akkulaufzeit erhöht werden? Dann drücke j!"
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Jj]$ ]]
then
	pakete=`echo "$pakete tlp tlp-rdw smartmontools ethtool"`
	service=`echo "$service tlp.service"`
	sudo flatpak -y install flathub com.github.d4nj1.tlpui
	#TODO Find PPA for TLPUI - https://github.com/d4nj1/TLPUI
fi

#no 22.04 yet
#y-ppa-manager
#Entfernen
#pluma löschen, da ersatz ist konsole und kate
#read -p "Soll pluma gelöscht werden? Dann drücke j!"
#echo    # (optional) move to a new line
#if [[ $REPLY =~ ^[Jj]$ ]]
#then
#	remove=`echo "$remove pluma*"`
#fi

paketerec="digikam exiv2 kipi-plugins graphicsmagick-imagemagick-compat hw-probe"
pakete=`echo "$pakete synaptic krita krita-l10n ubuntu-restricted-extras pidgin nfs-common language-pack-kde-de libdvd-pkg smartmontools unoconv mediathekview python3-axolotl python3-gnupg language-pack-de fonts-symbola vlc libxvidcore4 libfaac0 gnupg2 lutris dayon kate konsole element-desktop redshift-gtk"`
#remove=`echo "$remove"`

#sudo snap remove firefox
#sudo apt remove -y $remove

#Updaten
cd ~/Downloads/
sudo apt install -y wget apt-transport-https
sudo wget -O /usr/share/keyrings/element-io-archive-keyring.gpg https://packages.element.io/debian/element-io-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" | sudo tee /etc/apt/sources.list.d/element-io.list

sudo add-apt-repository -y ppa:regal/dayon

#no 22.04 yet
#sudo add-apt-repository -y ppa:webupd8team/y-ppa-manager

#Aktiviert die Standard Ubuntu Quellen für Fremd-Software-Entwickler
sudo add-apt-repository -y "deb http://archive.canonical.com/ubuntu $(lsb_release -sc) partner" 

echo $rep > rep.log

IFS=" "
oIFS=$IFS
for i in $rep; do
	sudo add-apt-repository -y $i
done
#fi

sudo apt-get update
sudo apt-get -y dist-upgrade
echo $paketerec > paketerec.log
sudo apt -y install --no-install-recommends $paketerec
echo $pakete > pakete.log
sudo apt -y install $pakete

#hide Dayon Assistant
sudo mv $config/usr/share/applications/dayon_assistant.desktop /usr/share/applications/

sudo update-alternatives --set x-terminal-emulator /usr/bin/konsole

sudo dpkg-reconfigure libdvd-pkg


#sudo snap install carnet

if [ ! -z $service ]
then
sudo systemctl enable $service
fi
sudo apt -y --fix-broken install
sudo dpkg-reconfigure -plow unattended-upgrades
sudo cp -f $config/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
sudo cp -f $config/firefoxUpdateOnShutdown.service /etc/systemd/system/firefoxUpdateOnShutdown.service
sudo systemctl daemon-reload
sudo systemctl enable firefoxUpdateOnShutdown.service

#Hardware probe
sudo -E hw-probe -all -upload
sudo apt-get purge -y hw-probe

#Aufräumen
rm -rf $verzeichnis/Install-Skript
